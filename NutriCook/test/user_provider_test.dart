import 'package:flutter_test/flutter_test.dart';
import 'package:nutricook/models/auth_user.dart';
import 'package:nutricook/models/user_preferences.dart';
import 'package:nutricook/providers/user_provider.dart';
import 'package:nutricook/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// A provider wired to a fake backend, so preference syncing succeeds without
/// a server.
UserProvider _provider([FakeRecipeService? service]) => UserProvider(
      storage: StorageService(),
      service: service ?? FakeRecipeService(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('cuisines', () {
    test('toggling one cuisine selects exactly that cuisine', () async {
      final user = _provider();
      await user.load();

      user.toggleCuisine('Indian');

      expect(user.preferences.cuisines, {'Indian'});
      expect(user.effectiveCuisines, ['Indian']);
    });

    test('accumulates several cuisines', () async {
      final user = _provider();
      await user.load();

      user
        ..toggleCuisine('Indian')
        ..toggleCuisine('Italian');

      expect(user.preferences.cuisines, {'Indian', 'Italian'});
    });

    test('toggling the same cuisine twice deselects it', () async {
      final user = _provider();
      await user.load();

      user
        ..toggleCuisine('Indian')
        ..toggleCuisine('Indian');

      expect(user.preferences.cuisines, isEmpty);
    });

    test('"Anything" clears specific cuisines, and vice versa', () async {
      final user = _provider();
      await user.load();

      user
        ..toggleCuisine('Indian')
        ..toggleCuisine('Italian')
        ..toggleCuisine('Anything');

      expect(user.preferences.cuisines, {'Anything'});
      // "Anything" is a sentinel, not a cuisine to send to the API.
      expect(user.effectiveCuisines, isEmpty);

      user.toggleCuisine('Mexican');
      expect(user.preferences.cuisines, {'Mexican'});
    });
  });

  group('allergies', () {
    test('"None" clears the rest, and picking one clears "None"', () async {
      final user = _provider();
      await user.load();

      user
        ..toggleAllergy('Milk')
        ..toggleAllergy('Peanuts');
      expect(user.preferences.allergies, {'Milk', 'Peanuts'});

      user.toggleAllergy('None');
      expect(user.preferences.allergies, {'None'});
      expect(user.effectiveAllergies, isEmpty);

      user.toggleAllergy('Gluten');
      expect(user.preferences.allergies, {'Gluten'});
      expect(user.effectiveAllergies, ['Gluten']);
    });
  });

  group('persistence', () {
    test('completing onboarding persists the answers', () async {
      final first = _provider();
      await first.load();
      first
        ..setGoal(LifestyleGoal.buildMuscle)
        ..setDiet(Diet.vegetarian)
        ..toggleCuisine('Indian')
        ..toggleAllergy('Peanuts');
      await first.completeOnboarding();

      final second = _provider();
      await second.load();

      expect(second.onboardingComplete, isTrue);
      expect(second.preferences.goal, LifestyleGoal.buildMuscle);
      expect(second.preferences.diet, Diet.vegetarian);
      expect(second.preferences.cuisines, {'Indian'});
      expect(second.preferences.allergies, {'Peanuts'});
    });

    test('completing onboarding reports a failed sync rather than lying',
        () async {
      // `onboarding_complete` lives on the account now, so a write that did
      // not reach the server must not be treated as done.
      final user = UserProvider(
        storage: StorageService(),
        service: OfflineRecipeService(),
      );
      await user.load();
      user.setGoal(LifestyleGoal.loseWeight);

      expect(await user.completeOnboarding(), isFalse);
      expect(user.onboardingComplete, isFalse);
    });

    test('the answers are sent to the account, not just stored locally',
        () async {
      final service = FakeRecipeService();
      final user = _provider(service);
      await user.load();
      user
        ..setGoal(LifestyleGoal.buildMuscle)
        ..setDiet(Diet.vegan);

      expect(await user.completeOnboarding(), isTrue);
      expect(service.lastOnboardingComplete, isTrue);
      expect(service.lastPreferences?['goal'], 'build_muscle');
      expect(service.lastPreferences?['diet'], 'vegan');
    });
  });

  group('account changes', () {
    test('signing in adopts the account\'s preferences', () async {
      final user = _provider();
      await user.load();

      user.syncWithAccount(
        const AuthUser(
          id: 'u1',
          preferences: UserPreferences(
            goal: LifestyleGoal.loseWeight,
            diet: Diet.pescatarian,
          ),
          onboardingComplete: true,
        ),
      );

      expect(user.preferences.goal, LifestyleGoal.loseWeight);
      expect(user.preferences.diet, Diet.pescatarian);
      expect(user.onboardingComplete, isTrue);
    });

    test('signing out clears them', () async {
      final user = _provider();
      await user.load();
      user.syncWithAccount(
        const AuthUser(
          id: 'u1',
          preferences: UserPreferences(goal: LifestyleGoal.buildMuscle),
          onboardingComplete: true,
        ),
      );

      user.syncWithAccount(null);

      expect(user.preferences.goal, isNull);
      expect(user.onboardingComplete, isFalse);
    });

    test('a different account replaces the previous one\'s answers',
        () async {
      // Two people on one device must never see each other's preferences.
      final user = _provider();
      await user.load();
      user.syncWithAccount(
        const AuthUser(
          id: 'first',
          preferences: UserPreferences(goal: LifestyleGoal.buildMuscle),
        ),
      );

      user.syncWithAccount(
        const AuthUser(
          id: 'second',
          preferences: UserPreferences(goal: LifestyleGoal.loseWeight),
        ),
      );

      expect(user.preferences.goal, LifestyleGoal.loseWeight);
    });

    test('onboarding is incomplete until goal and diet are chosen', () async {
      final user = _provider();
      await user.load();

      expect(user.preferences.isComplete, isFalse);
      user.setGoal(LifestyleGoal.eatHealthier);
      expect(user.preferences.isComplete, isFalse);
      user.setDiet(Diet.vegan);
      expect(user.preferences.isComplete, isTrue);
    });
  });
}
