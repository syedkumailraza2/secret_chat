/// A single recipe ingredient with its measurement.
///
/// The ingredient-selection screen also uses this type for pantry items, where
/// only [name] is meaningful and quantity/unit stay empty until the AI fills
/// them in on a generated recipe.
class Ingredient {
  final String name;
  final double quantity;
  final String unit;
  final bool optional;

  const Ingredient({
    required this.name,
    this.quantity = 0,
    this.unit = '',
    this.optional = false,
  });

  /// The measurement as the recipe detail screen shows it on the right-hand
  /// side of each row, e.g. "150g", "1/2 cup", "2 tsp".
  ///
  /// Whole numbers lose their trailing ".0" so "1.0 cup" reads as "1 cup".
  String get measurement {
    if (quantity <= 0) return unit;
    final q = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
    return unit.isEmpty ? q : '$q$_unitGap$unit';
  }

  /// Mass and volume abbreviations sit flush against the number ("150g"),
  /// spelled-out units take a space ("2 cups").
  String get _unitGap => (unit == 'g' || unit == 'ml' || unit == 'kg')
      ? ''
      : ' ';

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '',
      optional: json['optional'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'optional': optional,
      };

  @override
  bool operator ==(Object other) =>
      other is Ingredient &&
      other.name.toLowerCase() == name.toLowerCase();

  @override
  int get hashCode => name.toLowerCase().hashCode;
}
