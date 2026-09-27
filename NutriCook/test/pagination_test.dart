import 'package:flutter_test/flutter_test.dart';
import 'package:nutricook/models/browse_filters.dart';
import 'package:nutricook/models/nutrition.dart';
import 'package:nutricook/models/recipe.dart';
import 'package:nutricook/providers/explore_provider.dart';
import 'package:nutricook/providers/home_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

List<Recipe> _recipes(int count) => [
      for (var i = 0; i < count; i++)
        Recipe(
          id: 'r$i',
          name: 'Recipe $i',
          nutrition: const Nutrition(
            calories: 400,
            protein: 20,
            carbs: 50,
            fat: 12,
          ),
          servings: 2,
          cookingTime: 20,
          difficulty: 'Easy',
        ),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('feed pagination', () {
    test('the first load takes one page, not the whole feed', () async {
      final service = FakeRecipeService(feed: _recipes(25), pageSize: 10);
      final home = HomeProvider(service: service);

      await home.load();

      expect(home.recipes, hasLength(10));
      expect(home.hasMore, isTrue);
    });

    test('scrolling appends the next page', () async {
      final service = FakeRecipeService(feed: _recipes(25), pageSize: 10);
      final home = HomeProvider(service: service);
      await home.load();

      await home.loadMore();

      expect(home.recipes, hasLength(20));
      expect(home.hasMore, isTrue);
    });

    test('the last page closes the feed', () async {
      final service = FakeRecipeService(feed: _recipes(25), pageSize: 10);
      final home = HomeProvider(service: service);
      await home.load();
      await home.loadMore();

      await home.loadMore();

      expect(home.recipes, hasLength(25));
      expect(home.hasMore, isFalse);
    });

    test('no recipe is served twice across pages', () async {
      final service = FakeRecipeService(feed: _recipes(25), pageSize: 10);
      final home = HomeProvider(service: service);
      await home.load();
      await home.loadMore();
      await home.loadMore();

      final ids = home.recipes.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('loadMore does nothing once the feed is exhausted', () async {
      final service = FakeRecipeService(feed: _recipes(5), pageSize: 10);
      final home = HomeProvider(service: service);
      await home.load();
      final callsAfterLoad = service.feedCalls;

      await home.loadMore();

      expect(home.hasMore, isFalse);
      expect(service.feedCalls, callsAfterLoad);
    });

    test('overlapping scroll callbacks fire one request, not several',
        () async {
      // A fast scroll calls loadMore on every frame; each one must not
      // become its own page request.
      final service = FakeRecipeService(feed: _recipes(50), pageSize: 10);
      final home = HomeProvider(service: service);
      await home.load();
      final before = service.feedCalls;

      await Future.wait([home.loadMore(), home.loadMore(), home.loadMore()]);

      expect(service.feedCalls, before + 1);
    });

    test('refreshing starts a new shuffle rather than continuing the old one',
        () async {
      final service = FakeRecipeService(feed: _recipes(25), pageSize: 10);
      final home = HomeProvider(service: service);
      await home.load();
      await home.loadMore();
      expect(home.recipes, hasLength(20));

      await home.load();

      // Back to a single page, from the top of a fresh walk.
      expect(home.recipes, hasLength(10));
      expect(home.recipes.first.id, 'r0');
    });

    test('changing category reloads from the first page', () async {
      final service = FakeRecipeService(feed: _recipes(25), pageSize: 10);
      final home = HomeProvider(service: service);
      await home.load();
      await home.loadMore();

      await home.selectCategory('Breakfast');

      expect(home.recipes, hasLength(10));
      expect(home.selectedCategory, 'Breakfast');
    });

    test('a failed page leaves what is already on screen', () async {
      final service = FakeRecipeService(feed: _recipes(25), pageSize: 10);
      final home = HomeProvider(service: service);
      await home.load();

      // The next page fails.
      service.feed = [];
      await home.loadMore();

      expect(home.recipes, hasLength(10));
    });
  });

  group('explore filters', () {
    test('filters reach the service', () async {
      final service = FakeRecipeService(browseResults: _recipes(3));
      final explore = ExploreProvider(service: service);

      await explore.applyFilters(
        const BrowseFilters(
          category: 'dinner',
          difficulty: 'Easy',
          time: TimeFilter.under30,
          minProtein: 25,
          sort: BrowseSort.protein,
        ),
      );

      final sent = service.lastFilters!.toQuery();
      expect(sent['category'], 'dinner');
      expect(sent['difficulty'], 'Easy');
      expect(sent['max_cooking_time'], '30');
      expect(sent['min_protein'], '25');
      expect(sent['sort'], 'protein');
    });

    test('an unset filter is omitted rather than sent empty', () async {
      const filters = BrowseFilters();
      final sent = filters.toQuery();

      expect(sent.containsKey('category'), isFalse);
      expect(sent.containsKey('difficulty'), isFalse);
      expect(sent.containsKey('max_cooking_time'), isFalse);
      expect(sent.containsKey('q'), isFalse);
      expect(sent['sort'], 'recent');
    });

    test('applying the same filters twice does not refetch', () async {
      final service = FakeRecipeService(browseResults: _recipes(3));
      final explore = ExploreProvider(service: service);
      await explore.load();
      final before = service.browseCalls;

      await explore.applyFilters(explore.filters);

      expect(service.browseCalls, before);
    });

    test('clearing filters resets every one of them', () async {
      final service = FakeRecipeService(browseResults: _recipes(3));
      final explore = ExploreProvider(service: service);
      await explore.applyFilters(
        const BrowseFilters(
          query: 'curry',
          category: 'dinner',
          difficulty: 'Hard',
          time: TimeFilter.under15,
          maxCalories: 500,
          minProtein: 30,
          mineOnly: true,
          sort: BrowseSort.quick,
        ),
      );

      await explore.clearFilters();

      expect(explore.filters.isEmpty, isTrue);
      expect(explore.filters.activeCount, 0);
    });

    test('the active-filter count ignores the sort order', () async {
      // Sorting is always set to something, so counting it would show a
      // filter badge on an unfiltered screen.
      const sorted = BrowseFilters(sort: BrowseSort.protein);
      expect(sorted.activeCount, 0);

      const narrowed = BrowseFilters(
        category: 'dinner',
        minProtein: 30,
        sort: BrowseSort.protein,
      );
      expect(narrowed.activeCount, 2);
    });

    test('typing is debounced into a single request', () async {
      final service = FakeRecipeService(browseResults: _recipes(3));
      final explore = ExploreProvider(service: service);
      await explore.load();
      final before = service.browseCalls;

      explore
        ..setQuery('c')
        ..setQuery('cu')
        ..setQuery('cur')
        ..setQuery('curry');

      // Nothing has gone out yet.
      expect(service.browseCalls, before);

      await Future<void>.delayed(const Duration(milliseconds: 450));

      expect(service.browseCalls, before + 1);
      expect(service.lastFilters?.query, 'curry');
    });

    test('browse pages append rather than replace', () async {
      final service = FakeRecipeService(browseResults: _recipes(3));
      final explore = ExploreProvider(service: service);
      await explore.load();
      expect(explore.recipes, hasLength(3));

      // A second page with different recipes.
      service.browseResults = [
        Recipe(
          id: 'r99',
          name: 'Recipe 99',
          nutrition: const Nutrition(
            calories: 400,
            protein: 20,
            carbs: 50,
            fat: 12,
          ),
          servings: 2,
          cookingTime: 20,
          difficulty: 'Easy',
        ),
      ];
      explore.hasMore = true;
      await explore.loadMore();

      expect(explore.recipes.map((r) => r.id), containsAll(['r0', 'r99']));
    });
  });
}
