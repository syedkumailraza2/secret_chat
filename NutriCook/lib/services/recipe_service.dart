import '../core/constants/app_constants.dart';
import '../models/browse_filters.dart';
import '../models/recipe.dart';
import 'api_service.dart';

/// The parameters behind POST /api/recipes/generate.
class GenerateRequest {
  final List<String> ingredients;
  final String goal;
  final String meal;
  final int maxCookingTime;
  final int servings;
  final String? diet;
  final List<String> allergies;
  final List<String> cuisines;

  /// Set when the user has seen cached recipes for these exact inputs and
  /// asked for something new instead.
  final bool forceNew;

  const GenerateRequest({
    required this.ingredients,
    required this.goal,
    required this.meal,
    required this.maxCookingTime,
    required this.servings,
    this.diet,
    this.allergies = const [],
    this.cuisines = const [],
    this.forceNew = false,
  });

  GenerateRequest copyWith({bool? forceNew}) => GenerateRequest(
        ingredients: ingredients,
        goal: goal,
        meal: meal,
        maxCookingTime: maxCookingTime,
        servings: servings,
        diet: diet,
        allergies: allergies,
        cuisines: cuisines,
        forceNew: forceNew ?? this.forceNew,
      );

  Map<String, dynamic> toJson() => {
        'ingredients': ingredients,
        'goal': goal,
        'meal': meal,
        'max_cooking_time': maxCookingTime,
        'servings': servings,
        if (diet != null) 'diet': diet,
        'allergies': allergies,
        'cuisines': cuisines,
        'force_new': forceNew,
      };
}

/// Generated recipes, and whether they had been generated before.
class GenerationResult {
  final List<Recipe> recipes;

  /// True when an identical request had already been made — by anyone — and
  /// these are its results rather than fresh ones.
  final bool cached;

  const GenerationResult({required this.recipes, this.cached = false});
}

/// One page of the shuffled public feed.
class FeedPage {
  final List<Recipe> recipes;
  final String? nextCursor;
  final bool hasMore;

  const FeedPage({
    required this.recipes,
    this.nextCursor,
    this.hasMore = false,
  });

  static const empty = FeedPage(recipes: []);
}

/// One page of filtered browse results.
class BrowsePage {
  final List<Recipe> recipes;
  final int page;
  final int total;
  final bool hasMore;

  const BrowsePage({
    required this.recipes,
    required this.page,
    required this.total,
    this.hasMore = false,
  });
}

/// All recipe-related API calls. Widgets never talk to ApiService directly.
class RecipeService {
  final ApiService _api;

  RecipeService({ApiService? api}) : _api = api ?? ApiService();

  /// A page of the home feed. Pass the previous page's [cursor] to continue;
  /// omit it to start a fresh shuffle.
  Future<FeedPage> fetchFeed({
    String? category,
    String? cursor,
    int limit = AppConstants.feedPageSize,
  }) async {
    final json = await _api.get(
      '/api/recipes',
      query: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': '$limit',
      },
    );
    return FeedPage(
      recipes: _recipesFrom(json),
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  /// Community-generated recipes, filtered and sorted.
  Future<BrowsePage> browse({
    required BrowseFilters filters,
    int page = 1,
    int pageSize = AppConstants.browsePageSize,
  }) async {
    final json = await _api.get(
      '/api/recipes/browse',
      query: {
        ...filters.toQuery(),
        'page': '$page',
        'page_size': '$pageSize',
      },
    );
    return BrowsePage(
      recipes: _recipesFrom(json),
      page: (json['page'] as num?)?.toInt() ?? page,
      total: (json['total'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  Future<Recipe> fetchRecipe(String id) async {
    final json = await _api.get('/api/recipes/$id');
    return Recipe.fromJson(json);
  }

  /// Generates recipes from the user's pantry and preferences.
  ///
  /// Comes back without images — the caller then requests each photo through
  /// [generateImage] so results render immediately.
  Future<GenerationResult> generateRecipes(GenerateRequest request) async {
    final json = await _api.post(
      '/api/recipes/generate',
      body: request.toJson(),
      timeout: AppConstants.generateTimeout,
    );
    final recipes = _recipesFrom(json);
    if (recipes.isEmpty) {
      throw const ApiException(
        AppMessages.generateFailed,
        detail: 'empty recipe list',
      );
    }
    return GenerationResult(
      recipes: recipes,
      cached: json['cached'] as bool? ?? false,
    );
  }

  /// Generates and attaches the photo for one recipe.
  Future<String?> generateImage(String recipeId) async {
    final json = await _api.post(
      '/api/recipes/$recipeId/generate-image',
      timeout: AppConstants.imageTimeout,
    );
    return json['image_url'] as String?;
  }

  // --- User: preferences and saved recipes --------------------------------

  Future<List<Recipe>> fetchSavedRecipes() async {
    final json = await _api.get('/api/users/me/saved');
    return _recipesFrom(json);
  }

  Future<void> saveRecipe(String recipeId) async {
    await _api.post('/api/users/me/saved', body: {'recipe_id': recipeId});
  }

  Future<void> unsaveRecipe(String recipeId) async {
    await _api.delete('/api/users/me/saved/$recipeId');
  }

  Future<void> syncPreferences(
    Map<String, dynamic> preferences, {
    bool? onboardingComplete,
  }) async {
    await _api.put(
      '/api/users/me/preferences',
      body: {
        'preferences': preferences,
        'onboarding_complete': ?onboardingComplete,
      },
    );
  }

  List<Recipe> _recipesFrom(Map<String, dynamic> json) {
    final list = json['recipes'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Recipe.fromJson)
        .toList();
  }
}
