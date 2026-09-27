import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricook/models/ingredient.dart';
import 'package:nutricook/models/nutrition.dart';
import 'package:nutricook/models/recipe.dart';
import 'package:nutricook/providers/recipe_provider.dart';
import 'package:nutricook/providers/saved_provider.dart';
import 'package:nutricook/services/storage_service.dart';
import 'package:nutricook/widgets/nutrition_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // SavedProvider and UserProvider persist through SharedPreferences, which
    // needs an in-memory backing store under test.
    SharedPreferences.setMockInitialValues({});
  });

  group('Ingredient', () {
    test('formats mass units flush against the number', () {
      const ingredient =
          Ingredient(name: 'Paneer, cubed', quantity: 150, unit: 'g');
      expect(ingredient.measurement, '150g');
    });

    test('spaces spelled-out units and drops trailing zeros', () {
      const ingredient = Ingredient(name: 'Quinoa', quantity: 1, unit: 'cup');
      expect(ingredient.measurement, '1 cup');
    });

    test('keeps fractional quantities readable', () {
      const ingredient = Ingredient(name: 'Quinoa', quantity: 0.5, unit: 'cup');
      expect(ingredient.measurement, '0.5 cup');
    });
  });

  group('Recipe JSON', () {
    test('reads flat macros when no nested nutrition object is present', () {
      final recipe = Recipe.fromJson({
        'id': 'r1',
        'name': 'Test Bowl',
        'calories': 520,
        'protein': 28,
        'carbs': 62,
        'fat': 18,
        'cooking_time': 25,
        'servings': 2,
        'ingredients': [
          {'name': 'Paneer', 'quantity': 150, 'unit': 'g'},
        ],
        'instructions': ['Cook it.'],
      });

      expect(recipe.calories, 520);
      expect(recipe.protein, 28);
      expect(recipe.ingredients.single.name, 'Paneer');
      expect(recipe.instructions.single, 'Cook it.');
      expect(recipe.hasImage, isFalse);
    });

    test('survives a round trip through toJson', () {
      const original = Recipe(
        id: 'r2',
        name: 'Round Trip',
        nutrition: Nutrition(calories: 400, protein: 20, carbs: 40, fat: 12),
        cookingTime: 15,
        instructions: ['Step one'],
      );

      final restored = Recipe.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.calories, 400);
      expect(restored.instructions, ['Step one']);
    });
  });

  group('RecipeProvider', () {
    test('toggles ingredients on and off', () {
      final provider = RecipeProvider();

      provider.toggleIngredient('Paneer');
      expect(provider.isSelected('Paneer'), isTrue);

      provider.toggleIngredient('Paneer');
      expect(provider.isSelected('Paneer'), isFalse);
    });

    test('reset clears the whole flow', () {
      final provider = RecipeProvider()
        ..toggleIngredient('Rice')
        ..setServings(6)
        ..setMeal('breakfast');

      provider.reset();

      expect(provider.selectedIngredients, isEmpty);
      expect(provider.servings, 2);
      expect(provider.meal, 'dinner');
    });

    test('rejects out-of-range serving counts', () {
      final provider = RecipeProvider()..setServings(0);
      expect(provider.servings, 2);

      provider.setServings(99);
      expect(provider.servings, 2);
    });
  });

  group('SavedProvider', () {
    const recipe = Recipe(id: 'saved-1', name: 'Keeper');

    test('saves and unsaves', () async {
      final provider = SavedProvider(storage: StorageService());
      await provider.load();

      expect(provider.isSaved('saved-1'), isFalse);

      await provider.toggleSave(recipe);
      expect(provider.isSaved('saved-1'), isTrue);

      await provider.toggleSave(recipe);
      expect(provider.isSaved('saved-1'), isFalse);
    });

    test('persists saved recipes across instances', () async {
      final first = SavedProvider(storage: StorageService());
      await first.load();
      await first.toggleSave(recipe);

      final second = SavedProvider(storage: StorageService());
      await second.load();

      expect(second.isSaved('saved-1'), isTrue);
    });
  });

  testWidgets('NutritionCard reveals the secondary macros when expanded',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NutritionCard(
            nutrition: Nutrition(
              calories: 520,
              protein: 28,
              carbs: 62,
              fat: 18,
              fiber: 8,
              sugar: 6,
              sodium: 420,
              cholesterol: 35,
            ),
          ),
        ),
      ),
    );

    // The calorie figure is a Text.rich, so match its span content.
    expect(find.textContaining('520'), findsOneWidget);
    expect(find.text('28g'), findsOneWidget);

    await tester.tap(find.text('Nutrition per serving'));
    await tester.pumpAndSettle();

    expect(find.text('Fiber'), findsOneWidget);
    expect(find.text('420mg'), findsOneWidget);
  });
}
