/// How the Explore screen is sorted.
enum BrowseSort { recent, quick, protein, calories }

extension BrowseSortX on BrowseSort {
  String get apiValue => name;

  String get label => switch (this) {
        BrowseSort.recent => 'Newest',
        BrowseSort.quick => 'Quickest',
        BrowseSort.protein => 'Most protein',
        BrowseSort.calories => 'Lightest',
      };
}

/// A cooking-time ceiling offered on the Explore filter sheet.
enum TimeFilter { any, under15, under30, under60 }

extension TimeFilterX on TimeFilter {
  int? get maxMinutes => switch (this) {
        TimeFilter.any => null,
        TimeFilter.under15 => 15,
        TimeFilter.under30 => 30,
        TimeFilter.under60 => 60,
      };

  String get label => switch (this) {
        TimeFilter.any => 'Any time',
        TimeFilter.under15 => 'Under 15 min',
        TimeFilter.under30 => 'Under 30 min',
        TimeFilter.under60 => 'Under 60 min',
      };
}

/// Everything the Explore screen can narrow by.
///
/// Immutable so a changed filter is a new object — which makes "have the
/// filters actually changed?" a simple equality check rather than a pile of
/// field comparisons at each call site.
class BrowseFilters {
  final String query;
  final String? category;
  final String? difficulty;
  final TimeFilter time;
  final int? maxCalories;
  final int? minProtein;
  final bool mineOnly;
  final BrowseSort sort;

  const BrowseFilters({
    this.query = '',
    this.category,
    this.difficulty,
    this.time = TimeFilter.any,
    this.maxCalories,
    this.minProtein,
    this.mineOnly = false,
    this.sort = BrowseSort.recent,
  });

  /// True when nothing is narrowed — used to decide whether to show the
  /// "clear filters" affordance.
  bool get isEmpty =>
      query.isEmpty &&
      category == null &&
      difficulty == null &&
      time == TimeFilter.any &&
      maxCalories == null &&
      minProtein == null &&
      !mineOnly &&
      sort == BrowseSort.recent;

  /// How many chips to show on the filter button's badge. The sort is not
  /// counted — it always has a value, so it is never "a filter applied".
  int get activeCount => [
        query.isNotEmpty,
        category != null,
        difficulty != null,
        time != TimeFilter.any,
        maxCalories != null,
        minProtein != null,
        mineOnly,
      ].where((active) => active).length;

  /// `null` is a meaningful value for most of these, so each clearable field
  /// gets an explicit `clear` flag rather than relying on null-means-keep.
  BrowseFilters copyWith({
    String? query,
    String? category,
    bool clearCategory = false,
    String? difficulty,
    bool clearDifficulty = false,
    TimeFilter? time,
    int? maxCalories,
    bool clearMaxCalories = false,
    int? minProtein,
    bool clearMinProtein = false,
    bool? mineOnly,
    BrowseSort? sort,
  }) {
    return BrowseFilters(
      query: query ?? this.query,
      category: clearCategory ? null : (category ?? this.category),
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      time: time ?? this.time,
      maxCalories: clearMaxCalories ? null : (maxCalories ?? this.maxCalories),
      minProtein: clearMinProtein ? null : (minProtein ?? this.minProtein),
      mineOnly: mineOnly ?? this.mineOnly,
      sort: sort ?? this.sort,
    );
  }

  Map<String, String> toQuery() => {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'category': ?category,
        'difficulty': ?difficulty,
        if (time.maxMinutes != null)
          'max_cooking_time': '${time.maxMinutes}',
        if (maxCalories != null) 'max_calories': '$maxCalories',
        if (minProtein != null) 'min_protein': '$minProtein',
        if (mineOnly) 'mine': 'true',
        'sort': sort.apiValue,
      };

  @override
  bool operator ==(Object other) =>
      other is BrowseFilters &&
      other.query == query &&
      other.category == category &&
      other.difficulty == difficulty &&
      other.time == time &&
      other.maxCalories == maxCalories &&
      other.minProtein == minProtein &&
      other.mineOnly == mineOnly &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
        query,
        category,
        difficulty,
        time,
        maxCalories,
        minProtein,
        mineOnly,
        sort,
      );
}
