import 'package:flutter/foundation.dart';

import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../services/storage_service.dart';

/// Saved recipes.
///
/// The account is the record of truth — saves follow the user to any device —
/// but every change is written locally first so the screen stays responsive
/// and keeps working offline. A failed sync never loses the user's action; it
/// stays local until the next successful load.
class SavedProvider extends ChangeNotifier {
  final StorageService _storage;
  final RecipeService _service;

  SavedProvider({StorageService? storage, RecipeService? service})
      : _storage = storage ?? StorageService(),
        _service = service ?? RecipeService();

  List<Recipe> saved = [];
  bool isLoaded = false;

  /// True when the last server sync failed, so the list may be device-only.
  bool isOffline = false;

  /// Whose saves are currently held. Changing account must not leak the
  /// previous user's list onto the new one's screen.
  String? _userId;

  /// The filter chips on save-recipe.html.
  static const List<String> filters = [
    'All Saved',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snacks',
  ];

  String selectedFilter = 'All Saved';

  /// Reacts to sign-in and sign-out. Called whenever the auth state changes.
  ///
  /// The notification is deferred because this runs from a proxy provider's
  /// `update`, which happens during a build — and marking listeners dirty
  /// mid-build is an error.
  void syncWithAccount(String? userId) {
    if (userId == _userId) return;
    _userId = userId;

    if (userId == null) {
      // Signing out has to wipe the local cache too, or the next account to
      // sign in on this device would briefly see someone else's saves.
      saved = [];
      isLoaded = false;
      selectedFilter = 'All Saved';
      Future.microtask(() async {
        await _storage.clearSavedRecipes();
        notifyListeners();
      });
      return;
    }

    Future.microtask(load);
  }

  Future<void> load() async {
    // Local first so the screen paints immediately.
    saved = await _storage.loadSavedRecipes();
    isLoaded = true;
    notifyListeners();

    try {
      final remote = await _service.fetchSavedRecipes();
      saved = remote;
      isOffline = false;
      await _storage.saveRecipes(remote);
    } catch (_) {
      // Keep whatever is on the device; the user still sees their saves.
      isOffline = true;
    }
    notifyListeners();
  }

  bool isSaved(String id) => saved.any((r) => r.id == id);

  Future<void> toggleSave(Recipe recipe) async {
    final wasSaved = isSaved(recipe.id);

    if (wasSaved) {
      saved = saved.where((r) => r.id != recipe.id).toList();
    } else {
      // Newest first, matching how the design reads top-left to bottom-right.
      saved = [recipe, ...saved];
    }
    notifyListeners();
    await _storage.saveRecipes(saved);

    try {
      wasSaved
          ? await _service.unsaveRecipe(recipe.id)
          : await _service.saveRecipe(recipe.id);
      isOffline = false;
    } catch (_) {
      // The local change stands. Next successful load reconciles it.
      isOffline = true;
      notifyListeners();
    }
  }

  void selectFilter(String filter) {
    if (selectedFilter == filter) return;
    selectedFilter = filter;
    notifyListeners();
  }

  List<Recipe> get visible {
    if (selectedFilter == 'All Saved') return saved;
    final needle = selectedFilter.toLowerCase();
    return saved
        .where((r) => r.categories.any((c) => c.toLowerCase() == needle))
        .toList();
  }
}
