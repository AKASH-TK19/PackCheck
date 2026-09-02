import '../models/compliance_rule.dart';
import '../models/product_category.dart';

class ComplianceRules {
  /// The universal base rules that apply to every packaged commodity under the
  /// Legal Metrology (Packaged Commodities) Rules, 2011. These are always run
  /// regardless of category.
  static const List<ComplianceRule> universalRules = [
    ComplianceRule(
      id: 'LM-01',
      declaration: 'Manufacturer / Packer / Importer',
      description:
          'Name and address of the manufacturer, packer or importer should be declared.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
    ),
    ComplianceRule(
      id: 'LM-02',
      declaration: 'Country of Origin',
      description:
          'Country of origin should be declared for imported products.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
      conditional: true,
    ),
    ComplianceRule(
      id: 'LM-03',
      declaration: 'Common / Generic Name',
      description:
          'The common or generic name of the commodity should be identifiable.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
    ),
    ComplianceRule(
      id: 'LM-04',
      declaration: 'Net Quantity',
      description:
          'Net quantity should be declared in the applicable standard unit of weight, measure or number.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
    ),
    ComplianceRule(
      id: 'LM-05',
      declaration: 'Month / Year of Manufacture',
      description:
          'Month and year of manufacture/packing/import should be checked where applicable.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
    ),
    ComplianceRule(
      id: 'LM-07',
      declaration: 'Maximum Retail Price',
      description:
          'Retail sale price should be declared as Maximum Retail Price inclusive of applicable taxes.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
    ),
    ComplianceRule(
      id: 'LM-08',
      declaration: 'Consumer Care Details',
      description:
          'Consumer-care contact information should be present.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
    ),
  ];

  /// Food-specific rules that only apply to food / beverage categories.
  static const List<ComplianceRule> foodRules = [
    ComplianceRule(
      id: 'LM-06',
      declaration: 'Best Before / Use By',
      description:
          'Best-before or use-by declaration should be checked for commodities that may become unfit for human consumption.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
      conditional: true,
    ),
    ComplianceRule(
      id: 'LM-10',
      declaration: 'Unit Sale Price',
      description:
          'Unit sale price should be checked where applicable.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      conditional: true,
    ),
  ];

  /// Size/dimension rules that apply to readymade garments / hosiery.
  static const List<ComplianceRule> garmentRules = [
    ComplianceRule(
      id: 'CAT-GAR-01',
      declaration: 'Size / Fit Declaration',
      description:
          'Size (e.g. S/M/L/XL or numeric) should be declared on readymade garments.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
    ),
    ComplianceRule(
      id: 'CAT-GAR-02',
      declaration: 'Fiber Composition',
      description:
          'Fiber composition / material content should be declared on garments.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
    ),
    ComplianceRule(
      id: 'CAT-GAR-03',
      declaration: 'Washing / Care Instructions',
      description:
          'Care / washing instructions should be present on garments.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      conditional: true,
    ),
  ];

  /// Rules that apply to electronics (consumer durables, appliances, IT).
  static const List<ComplianceRule> electronicsRules = [
    ComplianceRule(
      id: 'CAT-ELC-01',
      declaration: 'Model / Serial Number',
      description:
          'Model or serial number should be declared for electronic products.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
    ),
    ComplianceRule(
      id: 'CAT-ELC-02',
      declaration: 'Warranty Details',
      description:
          'Warranty or guarantee terms should be declared for electronics.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      conditional: true,
    ),
    ComplianceRule(
      id: 'CAT-ELC-03',
      declaration: 'Importer / Marketer Detail',
      description:
          'Importer / authorised representative details should be present.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
    ),
  ];

  /// Rules that apply to electrical products.
  static const List<ComplianceRule> electricalRules = [
    ComplianceRule(
      id: 'CAT-ELE-01',
      declaration: 'Voltage / Rating Declaration',
      description:
          'Voltage, wattage and other electrical ratings should be declared.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
    ),
    ComplianceRule(
      id: 'CAT-ELE-02',
      declaration: 'Safety / Certification Mark',
      description:
          'A safety or certification mark (e.g. ISI, IS mark) should be present where applicable.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      conditional: true,
    ),
    ComplianceRule(
      id: 'CAT-ELE-03',
      declaration: 'Warranty / Guarantee',
      description:
          'Warranty or guarantee terms should be declared for electrical products.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      conditional: true,
    ),
  ];

  /// Rules that apply to cosmetics / personal care.
  static const List<ComplianceRule> cosmeticsRules = [
    ComplianceRule(
      id: 'CAT-COS-01',
      declaration: 'Ingredients / Composition',
      description:
          'Full list of ingredients should be declared for cosmetics.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
    ),
    ComplianceRule(
      id: 'CAT-COS-02',
      declaration: 'Manufacturing / Expiry Date',
      description:
          'Manufacture and expiry (or shelf-life) date should be declared.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
    ),
    ComplianceRule(
      id: 'CAT-COS-03',
      declaration: 'Manufacturing License / Authority',
      description:
          'Manufacturing license number or regulatory authority should be present.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      conditional: true,
    ),
  ];

  /// Rules that apply to household products.
  static const List<ComplianceRule> householdRules = [
    ComplianceRule(
      id: 'CAT-HSE-01',
      declaration: 'Usage Instructions',
      description:
          'Usage / handling instructions should be declared for household products.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
    ),
    ComplianceRule(
      id: 'CAT-HSE-02',
      declaration: 'Caution / Safety Warnings',
      description:
          'Caution and safety warnings should be present where applicable.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
      conditional: true,
    ),
    ComplianceRule(
      id: 'CAT-HSE-03',
      declaration: 'Batch / Lot Number',
      description:
          'Batch or lot number should be declared for household products.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      conditional: true,
    ),
  ];

  /// Returns the full ordered set of rules applicable to a given category.
  ///
  /// Universal Legal Metrology rules always apply. Food rules are added for the
  /// food/beverage categories, and category-specific rules are added when they
  /// have been implemented for that category.
  static List<ComplianceRule> rulesForCategory(ProductCategoryInfo? category) {
    final result = <ComplianceRule>[...universalRules];

    if (category == null) {
      return result;
    }

    if (category.isFood) {
      result.addAll(foodRules);
      return result;
    }

    switch (category.key) {
      case 'garments':
        result.addAll(garmentRules);
        break;
      case 'electronics':
        result.addAll(electronicsRules);
        break;
      case 'electrical':
        result.addAll(electricalRules);
        break;
      case 'cosmetics':
        result.addAll(cosmeticsRules);
        break;
      case 'household':
        result.addAll(householdRules);
        break;
      case 'other':
      default:
        // No category-specific rules; the advisory note is shown instead.
        break;
    }

    return result;
  }

  static const List<ComplianceRule> rules = [

    ComplianceRule(
      id: 'LM-01',
      declaration: 'Manufacturer / Packer / Importer',
      description:
          'Name and address of the manufacturer, packer or importer should be declared.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
    ),

    ComplianceRule(
      id: 'LM-02',
      declaration: 'Country of Origin',
      description:
          'Country of origin should be declared for imported products.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
      conditional: true,
    ),

    ComplianceRule(
      id: 'LM-03',
      declaration: 'Common / Generic Name',
      description:
          'The common or generic name of the commodity should be identifiable.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
    ),

    ComplianceRule(
      id: 'LM-04',
      declaration: 'Net Quantity',
      description:
          'Net quantity should be declared in the applicable standard unit of weight, measure or number.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
    ),

    ComplianceRule(
      id: 'LM-05',
      declaration: 'Month / Year of Manufacture',
      description:
          'Month and year of manufacture/packing/import should be checked where applicable.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
    ),

    ComplianceRule(
      id: 'LM-06',
      declaration: 'Best Before / Use By',
      description:
          'Best-before or use-by declaration should be checked for commodities that may become unfit for human consumption.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
      conditional: true,
    ),

    ComplianceRule(
      id: 'LM-07',
      declaration: 'Maximum Retail Price',
      description:
          'Retail sale price should be declared as Maximum Retail Price inclusive of applicable taxes.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
    ),

    ComplianceRule(
      id: 'LM-08',
      declaration: 'Consumer Care Details',
      description:
          'Consumer-care contact information should be present.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
    ),

    ComplianceRule(
      id: 'LM-09',
      declaration: 'Dimensions',
      description:
          'Dimensions should be declared where the size of the commodity is relevant.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      conditional: true,
    ),

    ComplianceRule(
      id: 'LM-10',
      declaration: 'Unit Sale Price',
      description:
          'Unit sale price should be checked where applicable.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      conditional: true,
    ),
  ];
}