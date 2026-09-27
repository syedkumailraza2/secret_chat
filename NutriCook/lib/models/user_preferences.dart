/// The lifestyle goal chosen during onboarding (onboarding2.html).
///
/// Distinct from the per-generation goal on create-preference.html — that one
/// is a property of a single recipe request, this one persists.
enum LifestyleGoal { eatHealthier, loseWeight, buildMuscle, maintainWeight }

/// The dietary style chosen during onboarding (onboarding3.html).
enum Diet { vegetarian, vegan, nonVegetarian, pescatarian }

extension LifestyleGoalX on LifestyleGoal {
  String get apiValue => switch (this) {
        LifestyleGoal.eatHealthier => 'eat_healthier',
        LifestyleGoal.loseWeight => 'lose_weight',
        LifestyleGoal.buildMuscle => 'build_muscle',
        LifestyleGoal.maintainWeight => 'maintain_weight',
      };

  String get label => switch (this) {
        LifestyleGoal.eatHealthier => 'Eat Healthier',
        LifestyleGoal.loseWeight => 'Lose Weight',
        LifestyleGoal.buildMuscle => 'Build Muscle',
        LifestyleGoal.maintainWeight => 'Maintain Weight',
      };

  static LifestyleGoal? fromApi(String? v) {
    for (final g in LifestyleGoal.values) {
      if (g.apiValue == v) return g;
    }
    return null;
  }
}

extension DietX on Diet {
  String get apiValue => switch (this) {
        Diet.vegetarian => 'vegetarian',
        Diet.vegan => 'vegan',
        Diet.nonVegetarian => 'non_vegetarian',
        Diet.pescatarian => 'pescatarian',
      };

  String get label => switch (this) {
        Diet.vegetarian => 'Vegetarian',
        Diet.vegan => 'Vegan',
        Diet.nonVegetarian => 'Non-Vegetarian',
        Diet.pescatarian => 'Pescatarian',
      };

  static Diet? fromApi(String? v) {
    for (final d in Diet.values) {
      if (d.apiValue == v) return d;
    }
    return null;
  }
}

/// Everything gathered during onboarding plus the cooking defaults shown on
/// the profile screen. Persisted locally via StorageService.
class UserPreferences {
  final LifestyleGoal? goal;
  final Diet? diet;
  final Set<String> allergies;
  final Set<String> cuisines;
  final int defaultServings;
  final int defaultCookingTime;

  const UserPreferences({
    this.goal,
    this.diet,
    this.allergies = const {},
    this.cuisines = const {},
    this.defaultServings = 2,
    this.defaultCookingTime = 30,
  });

  /// True once the user has made the two single-select choices onboarding
  /// requires. Allergies and cuisines are legitimately empty for some users.
  bool get isComplete => goal != null && diet != null;

  UserPreferences copyWith({
    LifestyleGoal? goal,
    Diet? diet,
    Set<String>? allergies,
    Set<String>? cuisines,
    int? defaultServings,
    int? defaultCookingTime,
  }) {
    return UserPreferences(
      goal: goal ?? this.goal,
      diet: diet ?? this.diet,
      allergies: allergies ?? this.allergies,
      cuisines: cuisines ?? this.cuisines,
      defaultServings: defaultServings ?? this.defaultServings,
      defaultCookingTime: defaultCookingTime ?? this.defaultCookingTime,
    );
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      goal: LifestyleGoalX.fromApi(json['goal'] as String?),
      diet: DietX.fromApi(json['diet'] as String?),
      allergies: (json['allergies'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet(),
      cuisines: (json['cuisines'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet(),
      defaultServings: (json['default_servings'] as num?)?.round() ?? 2,
      defaultCookingTime: (json['default_cooking_time'] as num?)?.round() ?? 30,
    );
  }

  Map<String, dynamic> toJson() => {
        'goal': goal?.apiValue,
        'diet': diet?.apiValue,
        'allergies': allergies.toList(),
        'cuisines': cuisines.toList(),
        'default_servings': defaultServings,
        'default_cooking_time': defaultCookingTime,
      };
}
