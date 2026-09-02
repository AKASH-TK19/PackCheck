import 'package:flutter/material.dart';

/// Metadata describing a single selectable product category.
///
/// Categories are grouped into two tiers of compliance awareness:
///
/// * [isFood] — the category is a packaged food/beverage commodity covered by
///   the food-specific Legal Metrology (Packaged Commodities) Rules checks.
/// * [hasCategorySpecificRules] — specific mandatory declarations are already
///   implemented for this category. When false, the category is treated as a
///   generic packaged commodity and the result is advisory only.
class ProductCategoryInfo {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final bool isFood;
  final bool hasCategorySpecificRules;

  const ProductCategoryInfo({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.isFood,
    required this.hasCategorySpecificRules,
  });

  /// True when the category should be shown the "advisory only" note because no
  /// category-specific rules have been implemented yet.
  bool get isAdvisoryOnly => !isFood && !hasCategorySpecificRules;
}

/// The fixed set of product categories offered on the mandatory selection
/// screen shown before any image capture / upload.
class ProductCategory {
  static const List<ProductCategoryInfo> all = [
    ProductCategoryInfo(
      key: 'food',
      label: 'Food Products',
      icon: Icons.fastfood,
      color: Color(0xFFE64A19),
      isFood: true,
      hasCategorySpecificRules: true,
    ),
    ProductCategoryInfo(
      key: 'beverages',
      label: 'Beverages',
      icon: Icons.local_drink,
      color: Color(0xFF29B6F6),
      isFood: true,
      hasCategorySpecificRules: true,
    ),
    ProductCategoryInfo(
      key: 'garments',
      label: 'Readymade Garments / Hosiery',
      icon: Icons.checkroom,
      color: Color(0xFF7E57C2),
      isFood: false,
      hasCategorySpecificRules: true,
    ),
    ProductCategoryInfo(
      key: 'electronics',
      label: 'Electronics',
      icon: Icons.devices_other,
      color: Color(0xFF26A69A),
      isFood: false,
      hasCategorySpecificRules: true,
    ),
    ProductCategoryInfo(
      key: 'electrical',
      label: 'Electrical Products',
      icon: Icons.power,
      color: Color(0xFFFFA726),
      isFood: false,
      hasCategorySpecificRules: true,
    ),
    ProductCategoryInfo(
      key: 'cosmetics',
      label: 'Cosmetics / Personal Care',
      icon: Icons.face_retouching_natural,
      color: Color(0xFFEC407A),
      isFood: false,
      hasCategorySpecificRules: true,
    ),
    ProductCategoryInfo(
      key: 'household',
      label: 'Household Products',
      icon: Icons.cleaning_services,
      color: Color(0xFF66BB6A),
      isFood: false,
      hasCategorySpecificRules: true,
    ),
    ProductCategoryInfo(
      key: 'other',
      label: 'Other Packaged Consumer Commodities',
      icon: Icons.category,
      color: Color(0xFF78909C),
      isFood: false,
      hasCategorySpecificRules: false,
    ),
  ];

  /// Looks up a category by its label. Returns null for an unknown value so the
  /// caller can degrade gracefully (e.g. an old record without a category).
  static ProductCategoryInfo? byLabel(String? label) {
    if (label == null) return null;

    final trimmed = label.trim();

    for (final category in all) {
      if (category.label == trimmed) return category;
    }

    return null;
  }

  /// Looks up a category by its stable [ProductCategoryInfo.key].
  static ProductCategoryInfo? byKey(String? key) {
    if (key == null) return null;

    for (final category in all) {
      if (category.key == key) return category;
    }

    return null;
  }
}
