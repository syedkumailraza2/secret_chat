import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/recipe_service.dart';

/// The home feed: a shuffled page of public recipes, extended as the user
/// scrolls, plus the active category chip.
class HomeProvider extends ChangeNotifier {
  final RecipeService _service;

  HomeProvider({RecipeService? service})
      : _service = service ?? RecipeService();

  List<Recipe> recipes = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  String? error;

  /// Where the current shuffle has got to. Null means the next load starts a
  /// new one, which is why pull-to-refresh reorders the feed.
  String? _cursor;

  /// The chip row on home.html. "Healthy" is selected by default there.
  static const List<String> categories = [
    'Healthy',
    'High Protein',
    'Quick',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snacks',
  ];

  String selectedCategory = 'Healthy';

  /// The card the design labels "Recipe of the Day".
  ///
  /// It is the first of the shuffle rather than a fixed pick, so it genuinely
  /// changes from visit to visit.
  Recipe? get featured => recipes.isEmpty ? null : recipes.first;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      // No cursor: a new walk, so the feed is reshuffled on every refresh.
      final page = await _service.fetchFeed(category: _categoryQuery);
      recipes = page.recipes;
      _cursor = page.nextCursor;
      hasMore = page.hasMore;
    } on ApiException catch (e) {
      error = e.message;
      recipes = [];
      _cursor = null;
      hasMore = false;
    } catch (_) {
      error = AppMessages.loadFeedFailed;
      recipes = [];
      _cursor = null;
      hasMore = false;
    }

    isLoading = false;
    notifyListeners();
  }

  /// Appends the next page. Safe to call from a scroll listener: overlapping
  /// calls are dropped rather than queued, so a fast scroll does not fire the
  /// same request several times.
  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !hasMore || _cursor == null) return;

    isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _service.fetchFeed(
        category: _categoryQuery,
        cursor: _cursor,
      );
      // The walk never repeats a recipe, but a page that arrives after the
      // feed was refreshed underneath it could. Guarding is cheap.
      final seen = recipes.map((r) => r.id).toSet();
      recipes = [
        ...recipes,
        ...page.recipes.where((r) => !seen.contains(r.id)),
      ];
      _cursor = page.nextCursor;
      hasMore = page.hasMore;
    } on ApiException {
      // Leave what is already on screen and stop asking for more; the user
      // can pull to refresh.
      hasMore = false;
    } catch (_) {
      hasMore = false;
    }

    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> selectCategory(String category) async {
    if (selectedCategory == category) return;
    selectedCategory = category;
    _cursor = null;
    notifyListeners();
    await load();
  }

  /// "Healthy" is the catch-all chip, so it sends no filter.
  String? get _categoryQuery => selectedCategory == 'Healthy'
      ? null
      : selectedCategory.toLowerCase().replaceAll(' ', '_');
}
