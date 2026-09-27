import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/recipe.dart';
import '../models/user_preferences.dart';

/// Local persistence: a cache, not the record of truth.
///
/// Saved recipes and preferences belong to the account and live in MongoDB.
/// They are mirrored here, whole rather than by id, so the saved screen still
/// renders while offline and paints instantly at launch instead of waiting on
/// a round trip.
class StorageService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  // --- Saved recipes -------------------------------------------------------

  Future<List<Recipe>> loadSavedRecipes() async {
    final prefs = await _instance;
    final raw = prefs.getString(AppConstants.kSavedRecipes);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Recipe.fromJson)
          .toList();
    } on FormatException {
      // Corrupt payload: drop it rather than trapping the user on a screen
      // that always throws.
      await prefs.remove(AppConstants.kSavedRecipes);
      return [];
    }
  }

  Future<void> saveRecipes(List<Recipe> recipes) async {
    final prefs = await _instance;
    await prefs.setString(
      AppConstants.kSavedRecipes,
      jsonEncode(recipes.map((r) => r.toJson()).toList()),
    );
  }

  /// Wipes the cached list on sign-out, so the next account on this device
  /// starts from its own saves rather than the previous user's.
  Future<void> clearSavedRecipes() async {
    final prefs = await _instance;
    await prefs.remove(AppConstants.kSavedRecipes);
  }

  // --- User preferences ----------------------------------------------------

  Future<UserPreferences?> loadPreferences() async {
    final prefs = await _instance;
    final raw = prefs.getString(AppConstants.kUserPreferences);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return UserPreferences.fromJson(decoded);
    } on FormatException {
      await prefs.remove(AppConstants.kUserPreferences);
      return null;
    }
  }

  Future<void> savePreferences(UserPreferences preferences) async {
    final prefs = await _instance;
    await prefs.setString(
      AppConstants.kUserPreferences,
      jsonEncode(preferences.toJson()),
    );
  }

  Future<void> clearPreferences() async {
    final prefs = await _instance;
    await prefs.remove(AppConstants.kUserPreferences);
    await prefs.remove(AppConstants.kOnboardingComplete);
  }

  // --- Onboarding ----------------------------------------------------------

  Future<bool> isOnboardingComplete() async {
    final prefs = await _instance;
    return prefs.getBool(AppConstants.kOnboardingComplete) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(AppConstants.kOnboardingComplete, value);
  }
}
