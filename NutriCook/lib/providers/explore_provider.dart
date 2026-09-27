import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/browse_filters.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/recipe_service.dart';

/// Drives the Explore screen: everything the community has generated,
/// narrowed by the filter sheet and extended page by page.
class ExploreProvider extends ChangeNotifier {
  final RecipeService _service;

  ExploreProvider({RecipeService? service})
      : _service = service ?? RecipeService();

  /// The category chips above the results. Sent lowercased with underscores,
  /// matching how generation tags them.
  static const List<String> categories = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snacks',
    'High Protein',
    'Low Carb',
    'Balanced',
  ];

  List<Recipe> recipes = [];
  BrowseFilters filters = const BrowseFilters();
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  int total = 0;
  String? error;

  int _page = 1;

  /// Typing should not fire a request per keystroke.
  Timer? _searchDebounce;

  /// Guards against an earlier, slower response overwriting a later one —
  /// which is exactly what happens when someone types quickly and the
  /// requests come back out of order.
  int _requestId = 0;

  bool get isEmpty => !isLoading && recipes.isEmpty && error == null;

  Future<void> load() async {
    final requestId = ++_requestId;

    isLoading = true;
    error = null;
    _page = 1;
    notifyListeners();

    try {
      final page = await _service.browse(filters: filters, page: 1);
      if (requestId != _requestId) return;
      recipes = page.recipes;
      total = page.total;
      hasMore = page.hasMore;
    } on ApiException catch (e) {
      if (requestId != _requestId) return;
      error = e.message;
      recipes = [];
      total = 0;
      hasMore = false;
    } catch (_) {
      if (requestId != _requestId) return;
      error = AppMessages.loadFeedFailed;
      recipes = [];
      total = 0;
      hasMore = false;
    }

    if (requestId != _requestId) return;
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !hasMore) return;

    final requestId = _requestId;
    isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _service.browse(filters: filters, page: _page + 1);
      // A filter changed while this was in flight; its results are stale.
      if (requestId != _requestId) return;
      _page += 1;
      final seen = recipes.map((r) => r.id).toSet();
      recipes = [
        ...recipes,
        ...page.recipes.where((r) => !seen.contains(r.id)),
      ];
      hasMore = page.hasMore;
      total = page.total;
    } on ApiException {
      hasMore = false;
    } catch (_) {
      hasMore = false;
    }

    if (requestId != _requestId) return;
    isLoadingMore = false;
    notifyListeners();
  }

  /// Applies a whole new filter set — what the filter sheet hands back.
  Future<void> applyFilters(BrowseFilters next) async {
    if (next == filters) return;
    filters = next;
    notifyListeners();
    await load();
  }

  void setQuery(String query) {
    if (query == filters.query) return;
    filters = filters.copyWith(query: query);
    notifyListeners();

    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      load,
    );
  }

  Future<void> setCategory(String? category) {
    return applyFilters(
      category == null
          ? filters.copyWith(clearCategory: true)
          : filters.copyWith(category: category),
    );
  }

  Future<void> setSort(BrowseSort sort) =>
      applyFilters(filters.copyWith(sort: sort));

  Future<void> clearFilters() {
    _searchDebounce?.cancel();
    return applyFilters(const BrowseFilters());
  }

  /// The chip label for a category value the API uses, and the reverse —
  /// kept together so the two conversions cannot drift apart.
  static String toApiCategory(String label) =>
      label.toLowerCase().replaceAll(' ', '_');

  static String fromApiCategory(String value) => categories.firstWhere(
        (label) => toApiCategory(label) == value,
        orElse: () => value,
      );

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
