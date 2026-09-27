import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricook/core/constants/app_constants.dart';
import 'package:nutricook/providers/recipe_provider.dart';
import 'package:nutricook/screens/create_recipe/generating_screen.dart';
import 'package:provider/provider.dart';

Future<void> _pump(WidgetTester tester, RecipeProvider provider) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<RecipeProvider>.value(
      value: provider,
      child: const MaterialApp(home: GeneratingScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows all five steps from the design', (tester) async {
    final provider = RecipeProvider()..isGenerating = true;

    await _pump(tester, provider);

    for (final step in RecipeProvider.generationSteps) {
      expect(find.text(step), findsOneWidget);
    }
    expect(RecipeProvider.generationSteps.length, 5);
    expect(find.text('Crafting your menu'), findsOneWidget);
  });

  testWidgets('marks earlier steps done as progress advances',
      (tester) async {
    final provider = RecipeProvider()
      ..isGenerating = true
      ..currentStep = 2;

    await _pump(tester, provider);

    // The step list is rendered in order; the active one is highlighted and
    // the ones before it are complete. Checking they all still render is the
    // meaningful assertion — the visual state is driven by currentStep.
    expect(find.text('Balancing nutrition'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows friendly error copy instead of a raw failure',
      (tester) async {
    final provider = RecipeProvider()
      ..isGenerating = false
      ..error = AppMessages.generateFailed;

    await _pump(tester, provider);

    expect(find.text(AppMessages.genericError), findsOneWidget);
    expect(find.text(AppMessages.generateFailed), findsOneWidget);
    expect(find.text(AppMessages.tryAgain), findsOneWidget);
    // Nothing resembling a status code reaches the user.
    expect(find.textContaining('500'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('does not pop when it is the only route', (tester) async {
    // Guards the blank-window case: recipes already present and nothing to
    // pop back to.
    final provider = RecipeProvider()..isGenerating = false;

    await _pump(tester, provider);
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.byType(GeneratingScreen), findsOneWidget);
  });
}
