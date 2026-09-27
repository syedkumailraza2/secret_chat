import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/explore_provider.dart';
import 'providers/home_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/saved_provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth/auth_welcome_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/auth_session.dart';
import 'services/auth_service.dart';
import 'services/recipe_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(NutriCookApp(session: AuthSession()));
}

class NutriCookApp extends StatelessWidget {
  /// Injectable so tests can start from a known session instead of whatever
  /// happens to be on the device.
  final AuthSession session;

  /// Injectable for the same reason: a widget test should exercise the real
  /// provider wiring without opening a socket.
  final RecipeService? recipeService;
  final AuthService? authService;

  const NutriCookApp({
    super.key,
    required this.session,
    this.recipeService,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    // One service stack, built around the session: every authenticated call
    // then carries the same token and shares the same silent refresh.
    final recipes =
        recipeService ?? RecipeService(api: ApiService(session: session));

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            service: authService,
            session: session,
          )..restore(),
        ),
        // Preferences and saves belong to the account, so both providers are
        // rebuilt against whoever is signed in — and cleared when nobody is.
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(service: recipes)..load(),
          update: (_, auth, user) => user!..syncWithAccount(auth.user),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SavedProvider>(
          create: (_) => SavedProvider(service: recipes),
          update: (_, auth, saved) => saved!..syncWithAccount(auth.user?.id),
        ),
        ChangeNotifierProvider(
          create: (_) => HomeProvider(service: recipes)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => ExploreProvider(service: recipes),
        ),
        ChangeNotifierProvider(
          create: (_) => RecipeProvider(service: recipes),
        ),
      ],
      child: MaterialApp(
        title: 'NutriCook',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: const _Entry(),
      ),
    );
  }
}

/// Chooses the front door: the welcome hero, the preference steps, or the app.
///
/// Driven by `AuthProvider.status`, so a session that lapses anywhere in the
/// app lands the user back on the welcome screen without every screen having
/// to check for itself.
class _Entry extends StatelessWidget {
  const _Entry();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;

    return switch (status) {
      // Reading stored tokens. A spinner would only flash, so this holds a
      // plain background for the frame or two it takes.
      AuthStatus.unknown => const Scaffold(
          backgroundColor: AppColors.background,
          body: SizedBox.shrink(),
        ),
      AuthStatus.signedOut => const AuthWelcomeScreen(),
      AuthStatus.onboarding => const OnboardingScreen(),
      AuthStatus.ready => const MainShell(),
    };
  }
}
