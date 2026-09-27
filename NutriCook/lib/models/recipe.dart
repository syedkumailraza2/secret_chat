import 'ingredient.dart';
import 'nutrition.dart';

class Recipe {
  final String id;
  final String name;
  final String description;

  /// Null while the backend is still generating the photo. The UI shows a
  /// loading state rather than a broken image in that window.
  final String? imageUrl;

  final Nutrition nutrition;
  final int servings;
  final int cookingTime;
  final String difficulty;
  final List<Ingredient> ingredients;
  final List<String> instructions;

  /// Feed grouping ("high_protein", "quick", "breakfast", …) used by the
  /// home-screen category chips.
  final List<String> categories;

  final double rating;
  final int reviewCount;

  /// True for recipes that came out of the AI generator rather than the
  /// pre-generated feed. Drives the "AI Adapted" badge in save-recipe.html.
  final bool aiGenerated;

  const Recipe({
    required this.id,
    required this.name,
    this.description = '',
    this.imageUrl,
    this.nutrition = const Nutrition(),
    this.servings = 2,
    this.cookingTime = 0,
    this.difficulty = 'Easy',
    this.ingredients = const [],
    this.instructions = const [],
    this.categories = const [],
    this.rating = 0,
    this.reviewCount = 0,
    this.aiGenerated = false,
  });

  // Convenience accessors so widgets don't reach through `nutrition` for the
  // three macros the cards show constantly.
  int get calories => nutrition.calories;
  double get protein => nutrition.protein;
  double get carbs => nutrition.carbs;
  double get fat => nutrition.fat;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  Recipe copyWith({String? imageUrl, Nutrition? nutrition}) {
    return Recipe(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl ?? this.imageUrl,
      nutrition: nutrition ?? this.nutrition,
      servings: servings,
      cookingTime: cookingTime,
      difficulty: difficulty,
      ingredients: ingredients,
      instructions: instructions,
      categories: categories,
      rating: rating,
      reviewCount: reviewCount,
      aiGenerated: aiGenerated,
    );
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // The API sends macros at the top level (matching the brief's response
    // shape) and optionally a richer `nutrition` object. Prefer the object
    // when present, fall back to the flat fields.
    final nutritionJson = json['nutrition'] as Map<String, dynamic>?;
    final nutrition = nutritionJson != null
        ? Nutrition.fromJson(nutritionJson)
        : Nutrition.fromJson(json);

    return Recipe(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      nutrition: nutrition,
      servings: (json['servings'] as num?)?.round() ?? 2,
      cookingTime: (json['cooking_time'] as num?)?.round() ?? 0,
      difficulty: json['difficulty'] as String? ?? 'Easy',
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Ingredient.fromJson)
          .toList(),
      instructions: (json['instructions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['review_count'] as num?)?.round() ?? 0,
      aiGenerated: json['ai_generated'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'nutrition': nutrition.toJson(),
        'calories': nutrition.calories,
        'protein': nutrition.protein,
        'carbs': nutrition.carbs,
        'fat': nutrition.fat,
        'servings': servings,
        'cooking_time': cookingTime,
        'difficulty': difficulty,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'instructions': instructions,
        'categories': categories,
        'rating': rating,
        'review_count': reviewCount,
        'ai_generated': aiGenerated,
      };
}
