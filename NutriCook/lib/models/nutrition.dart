/// Per-serving nutrition for a recipe.
///
/// These values are AI-estimated and then validated server-side by
/// `nutrition_service.py`. [estimated] records whether they came straight from
/// the model, so the UI can caveat them if it ever needs to.
class Nutrition {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final double cholesterol;
  final bool estimated;

  const Nutrition({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.cholesterol = 0,
    this.estimated = true,
  });

  factory Nutrition.fromJson(Map<String, dynamic> json) {
    double d(String k) => (json[k] as num?)?.toDouble() ?? 0;
    return Nutrition(
      calories: (json['calories'] as num?)?.round() ?? 0,
      protein: d('protein'),
      carbs: d('carbs'),
      fat: d('fat'),
      fiber: d('fiber'),
      sugar: d('sugar'),
      sodium: d('sodium'),
      cholesterol: d('cholesterol'),
      estimated: json['estimated'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
        'sodium': sodium,
        'cholesterol': cholesterol,
        'estimated': estimated,
      };
}
