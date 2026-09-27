import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricook/core/theme/app_dimens.dart';
import 'package:nutricook/models/ingredient.dart';
import 'package:nutricook/models/nutrition.dart';
import 'package:nutricook/models/recipe.dart';
import 'package:nutricook/widgets/recipe_card.dart';
import 'package:nutricook/widgets/recipe_meta.dart';

const _recipe = Recipe(
  id: 'r1',
  name: 'Creamy Chickpea Power Bowl',
  description: 'Golden spiced chickpeas over fresh greens.',
  nutrition: Nutrition(calories: 420, protein: 18, carbs: 52, fat: 14),
  servings: 2,
  cookingTime: 20,
  difficulty: 'Easy',
  ingredients: [Ingredient(name: 'Chickpeas', quantity: 400, unit: 'g')],
  instructions: ['Cook them.'],
);

/// Deliberately punishing content: a long name and wide numbers, to push the
/// cards' text handling at every width.
const _longRecipe = Recipe(
  id: 'r2',
  name: 'Slow-Roasted Mediterranean Vegetable and Chickpea Traybake with '
      'Herbed Tahini Dressing',
  nutrition: Nutrition(calories: 1250, protein: 88, carbs: 120, fat: 64),
  servings: 12,
  cookingTime: 240,
  difficulty: 'Medium',
  aiGenerated: true,
);

/// The phone sizes the app has to survive, smallest first.
const _sizes = <String, Size>{
  'iPhone SE': Size(320, 568),
  'iPhone 13 mini': Size(375, 812),
  'iPhone 17': Size(402, 874),
  'iPhone 17 Pro Max': Size(440, 956),
};

/// Reproduces the grid geometry SavedScreen computes, so the test exercises
/// the sizing the app actually ships.
double _savedGridExtent(double screenWidth, int columns) {
  final available = screenWidth - (AppSpacing.margin * 2);
  final itemWidth =
      (available - (AppSpacing.gutter * (columns - 1))) / columns;
  return itemWidth * 0.75 + 112;
}

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

void main() {
  group('FeaturedRecipeCard', () {
    // Regression: the card used StackFit.expand, which resolves to an infinite
    // height inside a scroll view and crashed the home screen on launch.
    testWidgets('lays out inside an unbounded ListView', (tester) async {
      await _pumpAt(
        tester,
        const Size(402, 874),
        ListView(
          children: [
            FeaturedRecipeCard(
              recipe: _recipe,
              isSaved: false,
              onTap: () {},
              onToggleSave: () {},
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Creamy Chickpea Power Bowl'), findsOneWidget);
    });

    testWidgets('honours its 300px minimum height', (tester) async {
      await _pumpAt(
        tester,
        const Size(402, 874),
        ListView(
          children: [
            FeaturedRecipeCard(
              recipe: _recipe,
              isSaved: false,
              onTap: () {},
              onToggleSave: () {},
            ),
          ],
        ),
      );

      expect(
        tester.getSize(find.byType(FeaturedRecipeCard)).height,
        greaterThanOrEqualTo(300),
      );
    });
  });

  group('cards survive every phone width', () {
    for (final entry in _sizes.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets('FeaturedRecipeCard on $name', (tester) async {
        await _pumpAt(
          tester,
          size,
          ListView(
            children: [
              FeaturedRecipeCard(
                recipe: _longRecipe,
                isSaved: true,
                onTap: () {},
                onToggleSave: () {},
              ),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('RecipeCard on $name', (tester) async {
        await _pumpAt(
          tester,
          size,
          ListView(
            children: [
              RecipeCard(
                recipe: _longRecipe,
                isSaved: false,
                isImagePending: true,
                onTap: () {},
                onToggleSave: () {},
              ),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
      });

      // Regression: a fixed 0.68 aspect ratio left only 29pt for the caption
      // at 320pt wide, overflowing the card by 43px.
      testWidgets('CompactRecipeCard grid on $name', (tester) async {
        await _pumpAt(
          tester,
          size,
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.margin,
            ),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.gutter,
                crossAxisSpacing: AppSpacing.gutter,
                mainAxisExtent: _savedGridExtent(size.width, 2),
              ),
              itemCount: 4,
              itemBuilder: (context, i) => CompactRecipeCard(
                recipe: _longRecipe,
                isSaved: true,
                onTap: () {},
                onToggleSave: () {},
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('MetaRow', () {
    testWidgets('wraps rather than overflowing on a narrow screen',
        (tester) async {
      await _pumpAt(
        tester,
        const Size(320, 568),
        const Padding(
          padding: EdgeInsets.all(AppSpacing.margin),
          child: MetaRow(cookingTime: 240, difficulty: 'Medium', servings: 12),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('240 min'), findsOneWidget);
      expect(find.text('12 servings'), findsOneWidget);
    });

    testWidgets('omits sections it has no data for', (tester) async {
      await _pumpAt(
        tester,
        const Size(402, 874),
        const MetaRow(cookingTime: 20),
      );

      expect(find.text('20 min'), findsOneWidget);
      expect(find.textContaining('servings'), findsNothing);
    });
  });
}
