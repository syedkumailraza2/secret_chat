import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../models/user_preferences.dart';
import '../services/recipe_service.dart';
import '../services/storage_service.dart';

/// Owns the onboarding answers and the account's preferences.
///
/// Preferences live on the account, so they follow the user between devices.
/// They are cached locally as well, which is what lets the profile screen
/// render before the first round trip finishes.
class UserProvider extends ChangeNotifier {
  final StorageService _storage;
  final RecipeService _service;

  UserProvider({StorageService? storage, RecipeService? service})
      : _storage = storage ?? StorageService(),
        _service = service ?? RecipeService();

  UserPreferences preferences = const UserPreferences();
  bool onboardingComplete = false;
  bool isLoaded = false;

  String? _userId;

  /// Reacts to sign-in and sign-out.
  ///
  /// On sign-in the server's copy wins: it is the one that survived the last
  /// reinstall, and it may have been changed on another device.
  /// Fields are set synchronously; the notification is deferred because this
  /// runs from a proxy provider's `update`, which happens during a build —
  /// and marking listeners dirty mid-build is an error.
  void syncWithAccount(AuthUser? user) {
    if (user?.id == _userId) return;
    _userId = user?.id;

    if (user == null) {
      preferences = const UserPreferences();
      onboardingComplete = false;
      isLoaded = false;
      Future.microtask(() async {
        await _storage.clearPreferences();
        notifyListeners();
      });
      return;
    }

    preferences = user.preferences;
    onboardingComplete = user.onboardingComplete;
    isLoaded = true;
    Future.microtask(() async {
      await _storage.savePreferences(preferences);
      notifyListeners();
    });
  }

  /// Reads the cached copy, so the app has something to show while the
  /// account is still being restored.
  Future<void> load() async {
    if (isLoaded) return;
    preferences = await _storage.loadPreferences() ?? const UserPreferences();
    onboardingComplete = await _storage.isOnboardingComplete();
    isLoaded = true;
    notifyListeners();
  }

  // --- Onboarding selections ----------------------------------------------

  void setGoal(LifestyleGoal goal) {
    preferences = preferences.copyWith(goal: goal);
    notifyListeners();
  }

  void setDiet(Diet diet) {
    preferences = preferences.copyWith(diet: diet);
    notifyListeners();
  }

  /// Allergies are multi-select, and "None" is mutually exclusive with the
  /// rest (onboarding4.html enforces the same rule in JS).
  void toggleAllergy(String allergy) {
    final next = Set<String>.from(preferences.allergies);
    if (allergy == 'None') {
      if (next.contains('None')) {
        next.clear();
      } else {
        next
          ..clear()
          ..add('None');
      }
    } else {
      next.remove('None');
      next.contains(allergy) ? next.remove(allergy) : next.add(allergy);
    }
    preferences = preferences.copyWith(allergies: next);
    notifyListeners();
  }

  /// Cuisines are multi-select, and "Anything" clears the rest
  /// (onboarding5.html behaves the same way).
  void toggleCuisine(String cuisine) {
    final next = Set<String>.from(preferences.cuisines);
    if (cuisine == 'Anything') {
      if (next.contains('Anything')) {
        next.clear();
      } else {
        next
          ..clear()
          ..add('Anything');
      }
    } else {
      next.remove('Anything');
      next.contains(cuisine) ? next.remove(cuisine) : next.add(cuisine);
    }
    preferences = preferences.copyWith(cuisines: next);
    notifyListeners();
  }

  void setDefaultServings(int servings) {
    if (servings < 1 || servings > 12) return;
    preferences = preferences.copyWith(defaultServings: servings);
    notifyListeners();
    _persist();
  }

  /// The real allergy list, with the "None" sentinel stripped — this is what
  /// goes to the API.
  List<String> get effectiveAllergies =>
      preferences.allergies.where((a) => a != 'None').toList();

  /// Cuisines with the "Anything" sentinel stripped.
  List<String> get effectiveCuisines =>
      preferences.cuisines.where((c) => c != 'Anything').toList();

  /// Finishes the preference steps.
  ///
  /// Returns false when the answers could not be saved to the account. That
  /// matters now that `onboarding_complete` lives on the server: pretending
  /// it worked would walk the user into the app and then ask them the same
  /// five questions again on their next launch.
  Future<bool> completeOnboarding() async {
    final synced = await _persist(onboardingComplete: true);
    if (!synced) return false;

    onboardingComplete = true;
    await _storage.setOnboardingComplete(true);
    notifyListeners();
    return true;
  }

  /// Mirrors preferences to the account, caching them locally either way.
  Future<bool> _persist({bool? onboardingComplete}) async {
    await _storage.savePreferences(preferences);
    try {
      await _service.syncPreferences(
        preferences.toJson(),
        onboardingComplete: onboardingComplete,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
