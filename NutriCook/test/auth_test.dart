import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricook/core/constants/app_constants.dart';
import 'package:nutricook/main.dart';
import 'package:nutricook/models/auth_user.dart';
import 'package:nutricook/models/ingredient.dart';
import 'package:nutricook/models/nutrition.dart';
import 'package:nutricook/models/recipe.dart';
import 'package:nutricook/models/user_preferences.dart';
import 'package:nutricook/providers/auth_provider.dart';
import 'package:nutricook/screens/auth/auth_welcome_screen.dart';
import 'package:nutricook/screens/main_shell.dart';
import 'package:nutricook/screens/onboarding/onboarding_screen.dart';
import 'package:nutricook/services/api_service.dart';
import 'package:nutricook/services/auth_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Pumps a bounded number of frames.
///
/// `pumpAndSettle` cannot be used on any screen showing a remote image: the
/// photo never loads under test, so its shimmer placeholder animates forever
/// and the call times out.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

const _recipe = Recipe(
  id: 'r1',
  name: 'Chickpea Bowl',
  nutrition: Nutrition(calories: 400, protein: 20, carbs: 50, fat: 12),
  servings: 2,
  cookingTime: 20,
  difficulty: 'Easy',
  ingredients: [Ingredient(name: 'Chickpeas', quantity: 200, unit: 'g')],
  instructions: ['Cook.'],
);

Future<AuthSession> _session({String? access, String? refresh}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.kAccessToken: ?access,
    AppConstants.kRefreshToken: ?refresh,
  });
  return AuthSession();
}

AuthProvider _provider(AuthSession session, FakeAuthService service) =>
    AuthProvider(service: service, session: session);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthProvider', () {
    test('no stored tokens means signed out', () async {
      final auth = _provider(await _session(), FakeAuthService());

      await auth.restore();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.isSignedIn, isFalse);
    });

    test('stored tokens are exchanged for a fresh pair at launch', () async {
      // Refreshing on restore settles two things at once: whether the session
      // is still good, and what the account looks like now.
      final service = FakeAuthService(
        user: const AuthUser(id: 'u1', onboardingComplete: true),
      );
      final session = await _session(access: 'old', refresh: 'old-refresh');
      final auth = _provider(session, service);

      await auth.restore();

      expect(service.refreshCalls, 1);
      expect(auth.status, AuthStatus.ready);
      expect(session.accessToken, isNot('old'));
    });

    test('a rejected refresh at launch signs the user out', () async {
      final service = FakeAuthService()
        ..failWith = const ApiException('nope', statusCode: 401);
      final session = await _session(access: 'old', refresh: 'dead');
      final auth = _provider(session, service);

      await auth.restore();

      expect(auth.status, AuthStatus.signedOut);
      expect(session.hasTokens, isFalse);
    });

    test('being offline at launch keeps the user signed in', () async {
      // A flaky connection is not a reason to throw somebody out; the next
      // 401 will settle it properly.
      final service = FakeAuthService()
        ..failWith = const ApiException(AppMessages.networkError);
      final session = await _session(access: 'still-good', refresh: 'r');
      final auth = _provider(session, service);

      await auth.restore();

      expect(auth.status, AuthStatus.ready);
      expect(session.hasTokens, isTrue);
    });

    test('a new account lands on onboarding, not the app', () async {
      final service = FakeAuthService(
        user: const AuthUser(id: 'u1', onboardingComplete: false),
      );
      final auth = _provider(await _session(), service);

      final created = await auth.signUp(
        email: 'chef@example.com',
        password: 'cast-iron-42',
        displayName: 'Ada',
      );

      expect(created, isTrue);
      expect(service.registerCalls, 1);
      expect(auth.status, AuthStatus.onboarding);
    });

    test('a returning account skips straight to the app', () async {
      final service = FakeAuthService(
        user: const AuthUser(id: 'u1', onboardingComplete: true),
      );
      final auth = _provider(await _session(), service);

      await auth.signIn(email: 'chef@example.com', password: 'cast-iron-42');

      expect(auth.status, AuthStatus.ready);
    });

    test('a failed sign-in surfaces the message and stays signed out',
        () async {
      final session = await _session();
      final service = FakeAuthService()
        ..failWith = const ApiException(
          AppMessages.signInFailed,
          statusCode: 401,
        );
      final auth = _provider(session, service);

      final signedIn = await auth.signIn(
        email: 'chef@example.com',
        password: 'wrong',
      );

      expect(signedIn, isFalse);
      expect(auth.error, AppMessages.signInFailed);
      expect(auth.isSignedIn, isFalse);
      expect(session.hasTokens, isFalse);
    });

    test('signing out revokes the token server-side and clears it locally',
        () async {
      final service = FakeAuthService();
      final session = await _session();
      final auth = _provider(session, service);
      await auth.signIn(email: 'chef@example.com', password: 'cast-iron-42');

      await auth.signOut();

      expect(service.logoutCalls, 1);
      expect(session.hasTokens, isFalse);
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.user, isNull);
    });

    test('a session that dies mid-use signs the user out', () async {
      // This is the path a failed silent refresh takes: the session clears
      // itself, and the provider has to notice without being asked.
      final service = FakeAuthService(
        user: const AuthUser(id: 'u1', onboardingComplete: true),
      );
      final session = await _session();
      final auth = _provider(session, service);
      await auth.signIn(email: 'chef@example.com', password: 'cast-iron-42');
      expect(auth.status, AuthStatus.ready);

      await session.clear();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.user, isNull);
    });

    test('finishing onboarding opens the app', () async {
      final service = FakeAuthService(
        user: const AuthUser(id: 'u1', onboardingComplete: false),
      );
      final auth = _provider(await _session(), service);
      await auth.signUp(email: 'a@b.com', password: 'cast-iron-42');
      expect(auth.status, AuthStatus.onboarding);

      auth.markOnboardingComplete(
        const UserPreferences(goal: LifestyleGoal.buildMuscle),
      );

      expect(auth.status, AuthStatus.ready);
      expect(auth.user?.onboardingComplete, isTrue);
      expect(auth.user?.preferences.goal, LifestyleGoal.buildMuscle);
    });
  });

  group('the front door', () {
    Future<void> pumpApp(
      WidgetTester tester, {
      required AuthSession session,
      required FakeAuthService auth,
    }) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        NutriCookApp(
          session: session,
          authService: auth,
          recipeService: FakeRecipeService(feed: [_recipe]),
        ),
      );
      await _settle(tester);
    }

    testWidgets('a signed-out launch shows the welcome hero', (tester) async {
      await pumpApp(
        tester,
        session: await _session(),
        auth: FakeAuthService(),
      );

      expect(find.byType(AuthWelcomeScreen), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.textContaining('Already have an account?'), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
    });

    testWidgets('a restored session with onboarding done opens the app',
        (tester) async {
      await pumpApp(
        tester,
        session: await _session(access: 'a', refresh: 'r'),
        auth: FakeAuthService(
          user: const AuthUser(id: 'u1', onboardingComplete: true),
        ),
      );

      expect(find.byType(MainShell), findsOneWidget);
      // All five destinations are reachable.
      for (final label in ['Home', 'Explore', 'Create', 'Saved', 'Profile']) {
        expect(find.text(label), findsOneWidget, reason: '$label tab');
      }
    });

    testWidgets('a restored session mid-onboarding resumes the steps',
        (tester) async {
      await pumpApp(
        tester,
        session: await _session(access: 'a', refresh: 'r'),
        auth: FakeAuthService(
          user: const AuthUser(id: 'u1', onboardingComplete: false),
        ),
      );

      expect(find.byType(OnboardingScreen), findsOneWidget);
      // Four preference steps: the welcome hero is the sign-in front door now.
      expect(find.text('STEP 1 OF 4'), findsOneWidget);
    });

    testWidgets('signing up walks through to the preference steps',
        (tester) async {
      await pumpApp(
        tester,
        session: await _session(),
        auth: FakeAuthService(
          user: const AuthUser(id: 'u1', onboardingComplete: false),
        ),
      );

      await tester.tap(find.text('Get Started'));
      await _settle(tester);

      expect(find.text('Create your account'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(1),
        'chef@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'cast-iron-42',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'cast-iron-42',
      );
      await tester.tap(find.text('Create Account'));
      await _settle(tester);

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('sign-up rejects a mismatched confirmation before sending',
        (tester) async {
      final auth = FakeAuthService();
      await pumpApp(tester, session: await _session(), auth: auth);

      await tester.tap(find.text('Get Started'));
      await _settle(tester);

      await tester.enterText(
        find.byType(TextFormField).at(1),
        'chef@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'cast-iron-42',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'something-else',
      );
      await tester.tap(find.text('Create Account'));
      await _settle(tester);

      expect(find.text("Those passwords don't match."), findsOneWidget);
      expect(auth.registerCalls, 0);
    });

    testWidgets('a rejected sign-in shows the reason on the form',
        (tester) async {
      final auth = FakeAuthService()
        ..failWith = const ApiException(
          AppMessages.signInFailed,
          statusCode: 401,
        );
      await pumpApp(tester, session: await _session(), auth: auth);

      await tester.tap(find.textContaining('Already have an account?'));
      await _settle(tester);

      expect(find.text('Welcome back'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'chef@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong-one');
      await tester.tap(find.text('Log In'));
      await _settle(tester);

      expect(find.text(AppMessages.signInFailed), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('an invalid email is caught before any request',
        (tester) async {
      final auth = FakeAuthService();
      await pumpApp(tester, session: await _session(), auth: auth);

      await tester.tap(find.textContaining('Already have an account?'));
      await _settle(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextFormField).at(1), 'whatever-12');
      await tester.tap(find.text('Log In'));
      await _settle(tester);

      expect(find.text("That doesn't look like an email."), findsOneWidget);
      expect(auth.loginCalls, 0);
    });
  });
}
