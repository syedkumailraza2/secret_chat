import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/recipe_service.dart';

/// The cooking-time bands offered on create-preference.html.
enum CookingTimeBand { under15, from15to30, from30to60 }

extension CookingTimeBandX on CookingTimeBand {
  String get label => switch (this) {
        CookingTimeBand.under15 => 'Under 15 min',
        CookingTimeBand.from15to30 => '15–30 min',
        CookingTimeBand.from30to60 => '30–60 min',
      };

  /// The upper bound sent to the API as `max_cooking_time`.
  int get maxMinutes => switch (this) {
        CookingTimeBand.under15 => 15,
        CookingTimeBand.from15to30 => 30,
        CookingTimeBand.from30to60 => 60,
      };
}

/// Drives the create-recipe flow: pantry selection, generation preferences,
/// the generation itself, and the resulting recipes.
class RecipeProvider extends ChangeNotifier {
  final RecipeService _service;

  RecipeProvider({RecipeService? service})
      : _service = service ?? RecipeService();

  // --- Ingredient selection (create-ingredient.html) -----------------------

  final Set<String> selectedIngredients = {};

  String searchQuery = '';

  void toggleIngredient(String ingredient) {
    selectedIngredients.contains(ingredient)
        ? selectedIngredients.remove(ingredient)
        : selectedIngredients.add(ingredient);
    notifyListeners();
  }

  void removeIngredient(String ingredient) {
    selectedIngredients.remove(ingredient);
    notifyListeners();
  }

  bool isSelected(String ingredient) =>
      selectedIngredients.contains(ingredient);

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  /// Adds a free-text ingredient the catalogue doesn't cover.
  void addCustomIngredient(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    selectedIngredients.add(trimmed);
    searchQuery = '';
    notifyListeners();
  }

  // --- Generation preferences (create-preference.html) ---------------------

  String goal = 'high_protein';
  String meal = 'dinner';
  CookingTimeBand timeBand = CookingTimeBand.from15to30;
  int servings = 2;

  void setGoal(String value) {
    goal = value;
    notifyListeners();
  }

  void setMeal(String value) {
    meal = value;
    notifyListeners();
  }

  void setTimeBand(CookingTimeBand value) {
    timeBand = value;
    notifyListeners();
  }

  void setServings(int value) {
    if (value < 1 || value > 12) return;
    servings = value;
    notifyListeners();
  }

  // --- Generation ----------------------------------------------------------

  /// The progress list on generating.html, in order.
  static const List<String> generationSteps = [
    'Checking your ingredients',
    'Understanding your preferences',
    'Balancing nutrition',
    'Creating recipes',
    'Calculating nutrition',
  ];

  List<Recipe> generatedRecipes = [];
  bool isGenerating = false;
  String? error;

  /// True when the recipes on screen came from a previous identical request
  /// rather than from the model just now. The results screen says so, and
  /// offers [regenerate].
  bool isCached = false;

  /// The request behind [generatedRecipes], kept so "generate fresh" can
  /// repeat it with the cache bypassed instead of walking the user back
  /// through the flow.
  GenerateRequest? _lastRequest;

  /// Index into [generationSteps] of the step currently in progress.
  int currentStep = 0;

  Timer? _stepTimer;

  /// Recipe ids whose photo is still being generated, so cards can show an
  /// image loading state instead of a gap.
  final Set<String> pendingImages = {};

  bool isImagePending(String id) => pendingImages.contains(id);

  Future<void> generateRecipes({
    String? diet,
    List<String> allergies = const [],
    List<String> cuisines = const [],
  }) {
    if (selectedIngredients.isEmpty) return Future.value();

    return _run(
      GenerateRequest(
        ingredients: selectedIngredients.toList(),
        goal: goal,
        meal: meal,
        maxCookingTime: timeBand.maxMinutes,
        servings: servings,
        diet: diet,
        allergies: allergies,
        cuisines: cuisines,
      ),
    );
  }

  /// The user declined the cached recipes and wants new ones.
  ///
  /// Repeats the same request with `force_new`, which is what makes the
  /// server skip its cache and actually call the model.
  Future<void> regenerate() {
    final request = _lastRequest;
    if (request == null || isGenerating) return Future.value();
    return _run(request.copyWith(forceNew: true));
  }

  Future<void> _run(GenerateRequest request) async {
    _lastRequest = request;

    isGenerating = true;
    error = null;
    generatedRecipes = [];
    isCached = false;
    currentStep = 0;
    notifyListeners();

    _startStepAnimation();

    try {
      final result = await _service.generateRecipes(request);

      _stopStepAnimation();
      currentStep = generationSteps.length - 1;
      generatedRecipes = result.recipes;
      isCached = result.cached;
      isGenerating = false;
      notifyListeners();

      // Photos arrive after the text so results render immediately.
      unawaited(_fetchImages(result.recipes));
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail(AppMessages.generateFailed);
    }
  }

  void _fail(String message) {
    _stopStepAnimation();
    error = message;
    isGenerating = false;
    generatedRecipes = [];
    isCached = false;
    notifyListeners();
  }

  /// Walks the progress list while the request is in flight. It stops one step
  /// short of the end so the list never claims to be finished before the
  /// response actually lands.
  void _startStepAnimation() {
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (currentStep < generationSteps.length - 2) {
        currentStep++;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  void _stopStepAnimation() {
    _stepTimer?.cancel();
    _stepTimer = null;
  }

  Future<void> _fetchImages(List<Recipe> recipes) async {
    for (final recipe in recipes) {
      if (recipe.hasImage) continue;
      pendingImages.add(recipe.id);
    }
    if (pendingImages.isEmpty) return;
    notifyListeners();

    // Sequential rather than parallel: image generation is expensive, and the
    // first card filling in quickly matters more than all three at once.
    for (final recipe in recipes) {
      if (recipe.hasImage) continue;
      try {
        final url = await _service.generateImage(recipe.id);
        final index = generatedRecipes.indexWhere((r) => r.id == recipe.id);
        if (url != null && url.isNotEmpty && index != -1) {
          generatedRecipes[index] =
              generatedRecipes[index].copyWith(imageUrl: url);
        }
      } catch (_) {
        // A missing photo is not worth failing the flow over; the card falls
        // back to its placeholder.
      } finally {
        pendingImages.remove(recipe.id);
        notifyListeners();
      }
    }
  }

  /// Clears the flow so "Create" always starts fresh.
  void reset() {
    _stopStepAnimation();
    selectedIngredients.clear();
    generatedRecipes = [];
    pendingImages.clear();
    searchQuery = '';
    error = null;
    isGenerating = false;
    isCached = false;
    _lastRequest = null;
    currentStep = 0;
    goal = 'high_protein';
    meal = 'dinner';
    timeBand = CookingTimeBand.from15to30;
    servings = 2;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopStepAnimation();
    super.dispose();
  }
}
