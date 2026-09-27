import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutricook/core/routes/app_routes.dart';
import 'package:nutricook/models/ingredient.dart';
import 'package:nutricook/models/nutrition.dart';
import 'package:nutricook/models/recipe.dart';
import 'package:nutricook/providers/auth_provider.dart';
import 'package:nutricook/providers/explore_provider.dart';
import 'package:nutricook/providers/home_provider.dart';
import 'package:nutricook/providers/recipe_provider.dart';
import 'package:nutricook/providers/saved_provider.dart';
import 'package:nutricook/providers/user_provider.dart';
import 'package:nutricook/screens/create_recipe/results_screen.dart';
import 'package:nutricook/screens/main_shell.dart';
import 'package:nutricook/screens/recipe/recipe_detail_screen.dart';
import 'package:nutricook/services/auth_session.dart';
import 'package:nutricook/services/storage_service.dart';
import 'package:nutricook/widgets/favorite_button.dart';
import 'package:nutricook/widgets/recipe_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

const _feedRecipe = Recipe(
  id: 'chickpea-power-bowl',
  name: 'Creamy Chickpea Power Bowl',
  description: 'Golden spiced chickpeas over fresh greens.',
  nutrition: Nutrition(calories: 420, protein: 18, carbs: 52, fat: 14),
  servings: 2,
  cookingTime: 20,
  difficulty: 'Easy',
  categories: ['healthy', 'lunch'],
  ingredients: [Ingredient(name: 'Chickpeas', quantity: 400, unit: 'g')],
  instructions: ['Crisp the chickpeas.', 'Assemble the bowl.'],
);

const _communityRecipe = Recipe(
  id: 'gen-community',
  name: 'Community Curry',
  description: 'Made by somebody else, shared with everyone.',
  nutrition: Nutrition(calories: 380, protein: 22, carbs: 44, fat: 11),
  servings: 2,
  cookingTime: 25,
  difficulty: 'Easy',
  categories: ['dinner'],
  ingredients: [Ingredient(name: 'Lentils', quantity: 200, unit: 'g')],
  instructions: ['Simmer everything.'],
  aiGenerated: true,
);

const _generated = Recipe(
  id: 'gen-abc123',
  name: 'Paneer Power Bowl',
  nutrition: Nutrition(calories: 520, protein: 32, carbs: 58, fat: 18),
  servings: 2,
  cookingTime: 25,
  difficulty: 'Easy',
  ingredients: [Ingredient(name: 'Paneer', quantity: 150, unit: 'g')],
  instructions: ['Sear the paneer.'],
  aiGenerated: true,
);

Future<Widget> _app(FakeRecipeService service) async {
  final session = AuthSession();
  await session.load();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => AuthProvider(
          service: FakeAuthService(),
          session: session,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            UserProvider(storage: StorageService(), service: service),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            SavedProvider(storage: StorageService(), service: service)..load(),
      ),
      ChangeNotifierProvider(
        create: (_) => HomeProvider(service: service)..load(),
      ),
      ChangeNotifierProvider(
        create: (_) => ExploreProvider(service: service),
      ),
      ChangeNotifierProvider(create: (_) => RecipeProvider(service: service)),
    ],
    child: MaterialApp(
      // Matches main.dart: detail routes are pushed on the root navigator.
      onGenerateRoute: AppRoutes.onGenerateRoute,
      home: const MainShell(),
    ),
  );
}

void _phoneSized(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('browse → open recipe → save → find it under Saved',
      (tester) async {
    _phoneSized(tester);

    final service = FakeRecipeService(feed: [_feedRecipe]);
    await tester.pumpWidget(await _app(service));
    await tester.pumpAndSettle();

    // Home shows the featured recipe.
    expect(find.text('Creamy Chickpea Power Bowl'), findsOneWidget);

    // Opening it reaches the detail screen with its ingredients and steps.
    await tester.tap(find.byType(FeaturedRecipeCard));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    expect(find.text('Ingredients'), findsOneWidget);
    expect(find.text('Instructions'), findsOneWidget);
    expect(find.text('Crisp the chickpeas.'), findsOneWidget);

    // Saving it, then going back.
    await tester.tap(find.byType(FavoriteButton).first);
    await tester.pumpAndSettle();
    // The design uses a custom circular back control, not a stock AppBar
    // back button, so pageBack() cannot find it.
    await tester.tap(find.byIcon(Symbols.arrow_back));
    await tester.pumpAndSettle();

    // The Saved tab now lists it.
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    expect(find.text('Saved Recipes'), findsOneWidget);
    expect(find.byType(CompactRecipeCard), findsOneWidget);
  });

  testWidgets('home has no search field', (tester) async {
    // Removed by request. Searching lives on Explore, which queries the whole
    // library server-side rather than filtering the page Home happens to hold.
    _phoneSized(tester);

    final service = FakeRecipeService(feed: [_feedRecipe]);
    await tester.pumpWidget(await _app(service));
    await tester.pumpAndSettle();

    expect(find.text('Search recipes...'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    // The rest of the screen is intact.
    expect(find.textContaining('What are you cooking today?'), findsOneWidget);
    expect(find.byType(FeaturedRecipeCard), findsOneWidget);
  });

  testWidgets('recipe detail has no cooking CTA', (tester) async {
    _phoneSized(tester);

    final service = FakeRecipeService(feed: [_feedRecipe]);
    await tester.pumpWidget(await _app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FeaturedRecipeCard));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    // The screen ends with the instructions; there is no Start Cooking
    // button and nothing that implies a cooking mode.
    expect(find.text('Start Cooking'), findsNothing);
    expect(find.textContaining('coming soon'), findsNothing);
    expect(find.text('Instructions'), findsOneWidget);
  });

  testWidgets('create flow: ingredients gate the Continue button',
      (tester) async {
    _phoneSized(tester);

    final service = FakeRecipeService(feed: [_feedRecipe]);
    await tester.pumpWidget(await _app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('What do you have?'), findsOneWidget);

    // Nothing selected yet, so continuing does nothing.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What do you have?'), findsOneWidget);

    // Selecting an ingredient enables the flow.
    await tester.tap(find.text('Paneer'));
    await tester.pumpAndSettle();
    expect(find.text('You have'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('What are you looking for?'), findsOneWidget);
  });

  testWidgets('generation sends the user\'s ingredients and preferences',
      (tester) async {
    final service = FakeRecipeService(generated: [_generated]);
    final provider = RecipeProvider(service: service)
      ..toggleIngredient('Paneer')
      ..toggleIngredient('Rice')
      ..setGoal('high_protein')
      ..setMeal('dinner')
      ..setServings(4)
      ..setTimeBand(CookingTimeBand.under15);

    await provider.generateRecipes(
      diet: 'vegetarian',
      allergies: ['Peanuts'],
      cuisines: ['Indian'],
    );

    expect(service.generateCalls, 1);

    final request = service.lastRequest!;
    expect(request.ingredients, containsAll(['Paneer', 'Rice']));
    expect(request.goal, 'high_protein');
    expect(request.meal, 'dinner');
    expect(request.servings, 4);
    expect(request.maxCookingTime, 15);
    expect(request.diet, 'vegetarian');
    expect(request.allergies, ['Peanuts']);
    expect(request.cuisines, ['Indian']);
    // The first attempt always lets the cache answer.
    expect(request.forceNew, isFalse);

    expect(provider.generatedRecipes.single.name, 'Paneer Power Bowl');
    expect(provider.isGenerating, isFalse);
    expect(provider.error, isNull);
  });

  group('cached results', () {
    testWidgets('the results screen says when recipes were reused',
        (tester) async {
      _phoneSized(tester);

      final service = FakeRecipeService(
        generated: [_generated],
        cached: true,
      );
      final provider = RecipeProvider(service: service)
        ..toggleIngredient('Paneer');
      await provider.generateRecipes();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider(
              create: (_) => SavedProvider(
                storage: StorageService(),
                service: service,
              ),
            ),
          ],
          child: const MaterialApp(home: ResultsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Already cooked up'), findsOneWidget);
      expect(find.text('Generate something fresh'), findsOneWidget);
    });

    testWidgets('fresh results carry no banner', (tester) async {
      _phoneSized(tester);

      final service = FakeRecipeService(generated: [_generated]);
      final provider = RecipeProvider(service: service)
        ..toggleIngredient('Paneer');
      await provider.generateRecipes();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider(
              create: (_) => SavedProvider(
                storage: StorageService(),
                service: service,
              ),
            ),
          ],
          child: const MaterialApp(home: ResultsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Already cooked up'), findsNothing);
      expect(find.text('Made for you ✨'), findsOneWidget);
    });

    test('declining cached recipes asks the server to skip its cache',
        () async {
      final service = FakeRecipeService(
        generated: [_generated],
        cached: true,
      );
      final provider = RecipeProvider(service: service)
        ..toggleIngredient('Paneer')
        ..setServings(3);

      await provider.generateRecipes(diet: 'vegan');
      expect(provider.isCached, isTrue);

      service.cached = false;
      await provider.regenerate();

      expect(service.generateCalls, 2);
      expect(provider.isCached, isFalse);

      // The second attempt repeats the first request exactly, bar the flag —
      // otherwise "something else" would silently become "something for
      // different preferences".
      final second = service.lastRequest!;
      expect(second.forceNew, isTrue);
      expect(second.servings, 3);
      expect(second.diet, 'vegan');
      expect(second.ingredients, ['Paneer']);
    });

    test('regenerating before anything was generated does nothing', () async {
      final service = FakeRecipeService(generated: [_generated]);
      final provider = RecipeProvider(service: service);

      await provider.regenerate();

      expect(service.generateCalls, 0);
    });
  });

  group('explore', () {
    testWidgets('the tab lists community recipes', (tester) async {
      _phoneSized(tester);

      final service = FakeRecipeService(
        feed: [_feedRecipe],
        browseResults: [_communityRecipe],
      );
      await tester.pumpWidget(await _app(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      expect(find.text('Community Curry'), findsOneWidget);
      expect(find.text('1 recipe'), findsOneWidget);
    });

    testWidgets('choosing a category filters the request', (tester) async {
      _phoneSized(tester);

      final service = FakeRecipeService(
        feed: [_feedRecipe],
        browseResults: [_communityRecipe],
      );
      await tester.pumpWidget(await _app(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // The chip row scrolls horizontally; Breakfast is the first chip
      // after "All", so it is on screen without dragging.
      await tester.tap(find.text('Breakfast'));
      await tester.pumpAndSettle();

      expect(service.lastFilters?.category, 'breakfast');
    });

    testWidgets('an empty library explains itself', (tester) async {
      _phoneSized(tester);

      final service = FakeRecipeService(feed: [_feedRecipe]);
      await tester.pumpWidget(await _app(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Create a recipe'), findsOneWidget);
    });
  });
}
