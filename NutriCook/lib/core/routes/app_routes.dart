import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/sign_up_screen.dart';
import '../../screens/create_recipe/generating_screen.dart';
import '../../screens/create_recipe/ingredients_screen.dart';
import '../../screens/create_recipe/preferences_screen.dart';
import '../../screens/create_recipe/results_screen.dart';
import '../../screens/main_shell.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/recipe/recipe_detail_screen.dart';

/// Centralised route names and navigation helpers.
///
/// Plain Navigator rather than a routing package — the app is small enough
/// that a table of names and a few typed helpers is clearer.
class AppRoutes {
  AppRoutes._();

  static const String onboarding = '/onboarding';
  static const String main = '/';
  static const String signUp = '/auth/sign-up';
  static const String logIn = '/auth/log-in';
  static const String recipeDetail = '/recipe';
  static const String createIngredients = '/create/ingredients';
  static const String createPreferences = '/create/preferences';
  static const String createGenerating = '/create/generating';
  static const String createResults = '/create/results';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case onboarding:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const OnboardingScreen(),
        );

      case main:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainShell(),
        );

      case signUp:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SignUpScreen(),
        );

      case logIn:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );

      case recipeDetail:
        final recipe = settings.arguments as Recipe;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RecipeDetailScreen(recipe: recipe),
        );

      case createIngredients:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const IngredientsScreen(),
        );

      case createPreferences:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const PreferencesScreen(),
        );

      case createGenerating:
        return MaterialPageRoute(
          settings: settings,
          fullscreenDialog: true,
          builder: (_) => const GeneratingScreen(),
        );

      case createResults:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ResultsScreen(),
        );
    }
    return null;
  }

  // --- Typed helpers -------------------------------------------------------

  static Future<void> openRecipe(BuildContext context, Recipe recipe) {
    return Navigator.of(context, rootNavigator: true)
        .pushNamed(recipeDetail, arguments: recipe);
  }

  static void goToMain(BuildContext context) {
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil(main, (route) => false);
  }
}
