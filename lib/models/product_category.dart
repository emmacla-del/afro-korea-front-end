enum ProductCategory {
  FOOD_PRODUCE,
  TRANSFORMED_FOOD,
  HOUSEHOLD_EQUIPMENT,
  CONSTRUCTION_MATERIAL,
  ELECTRONICS,
}

extension ProductCategoryExtension on ProductCategory {
  /// User‑friendly display name (e.g., "Food Produce")
  String get displayName {
    switch (this) {
      case ProductCategory.FOOD_PRODUCE:
        return 'Food Produce';
      case ProductCategory.TRANSFORMED_FOOD:
        return 'Transformed Food';
      case ProductCategory.HOUSEHOLD_EQUIPMENT:
        return 'Household Equipment';
      case ProductCategory.CONSTRUCTION_MATERIAL:
        return 'Construction Material';
      case ProductCategory.ELECTRONICS:
        return 'Electronics';
    }
  }

  /// Raw enum string as sent by the backend (e.g., "FOOD_PRODUCE")
  String get rawValue => toString().split('.').last;

  /// Parse from backend string
  static ProductCategory? fromRaw(String? raw) {
    if (raw == null) return null;
    try {
      return ProductCategory.values.firstWhere(
        (e) => e.rawValue == raw,
        orElse: () => throw Exception('Unknown category: $raw'),
      );
    } catch (e) {
      return null;
    }
  }
}
