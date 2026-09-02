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
      prescribedDeclaration:
          "Manufacturer's name and complete address",
      whyItMatters:
          'Consumers must be able to identify who is responsible for the pack, and regulators need it for recall / accountability.',
      howToFix:
          'Verify that the manufacturer\u2019s name and complete address are clearly declared on the package.',
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
      prescribedDeclaration: 'Country of origin (e.g. Made in India)',
      whyItMatters:
          'Imported pre-packaged commodities must state their country of origin so consumers can make an informed choice.',
      howToFix:
          'If the product is imported, ensure the country of origin is printed on the package.',
    ),
    ComplianceRule(
      id: 'LM-03',
      declaration: 'Common / Generic Name',
      description:
          'The common or generic name of the commodity should be identifiable.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      prescribedDeclaration: 'Common or generic product name',
      whyItMatters:
          'The package must clearly state the common or generic name of the commodity so the consumer knows exactly what they are buying.',
      howToFix:
          'Ensure the common or generic name of the product is legible on the main face of the package.',
    ),
    ComplianceRule(
      id: 'LM-04',
      declaration: 'Net Quantity',
      description:
          'Net quantity should be declared in the applicable standard unit of weight, measure or number.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
      prescribedDeclaration:
          'Net quantity in a standard unit (e.g. g, kg, ml, l, pcs)',
      whyItMatters:
          'Net quantity is a mandatory declaration that lets consumers compare price and value between products.',
      howToFix:
          'The package should contain the required net quantity declaration in an applicable standard unit.',
    ),
    ComplianceRule(
      id: 'LM-05',
      declaration: 'Month / Year of Manufacture',
      description:
          'Month and year of manufacture/packing/import should be checked where applicable.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      prescribedDeclaration:
          'Month & year of manufacture / packing (e.g. MFG 05/2025)',
      whyItMatters:
          'The date of manufacture or packing is needed to assess freshness and shelf-life.',
      howToFix:
          'Ensure the month and year of manufacture or packing are declared on the package.',
    ),
    ComplianceRule(
      id: 'LM-07',
      declaration: 'Maximum Retail Price',
      description:
          'Retail sale price should be declared as Maximum Retail Price inclusive of applicable taxes.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
      prescribedDeclaration:
          'Maximum Retail Price (MRP) inclusive of all taxes',
      whyItMatters:
          'MRP protects consumers from overcharging; the retail price must be declared including all applicable taxes.',
      howToFix:
          'Verify the Maximum Retail Price (MRP), inclusive of all taxes, is printed on the package.',
    ),
    ComplianceRule(
      id: 'LM-08',
      declaration: 'Consumer Care Details',
      description:
          'Consumer-care contact information should be present.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      prescribedDeclaration:
          'Consumer care phone / email / address',
      whyItMatters:
          'Consumers need a way to reach the manufacturer with complaints, refills or grievances.',
      howToFix:
          'Add a consumer-care contact (phone, email or address) to the package.',
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
      prescribedDeclaration:
          'Best before / use by date (or shelf life)',
      whyItMatters:
          'Perishable commodities must state their best-before or use-by date so consumers can judge freshness and safety.',
      howToFix:
          'If the commodity is perishable, declare a best-before or use-by date on the package.',
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
      prescribedDeclaration:
          'Unit sale price (price per unit of measure)',
      whyItMatters:
          'The unit sale price lets consumers compare value across differently sized packs.',
      howToFix:
          'Declare a unit sale price (price per unit of weight/volume) where required.',
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
      prescribedDeclaration: 'Size / fit (S, M, L, XL, XXL or a numeric size)',
      whyItMatters:
          'A visible size declaration lets the consumer pick the correct fit when buying readymade garments.',
      howToFix:
          'Ensure the size or fit is clearly printed on the garment label.',
    ),
    ComplianceRule(
      id: 'CAT-GAR-02',
      declaration: 'Fiber Composition',
      description:
          'Fiber composition / material content should be declared on garments.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      prescribedDeclaration: 'Fiber composition / material content (%)',
      whyItMatters:
          'The material composition helps consumers judge quality, care needs and allergy risks.',
      howToFix:
          'Declare the fiber composition or material content on the garment label.',
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
      prescribedDeclaration: 'Care / washing instructions',
      whyItMatters:
          'Care instructions help the consumer preserve the garment and prevent damage.',
      howToFix:
          'Add washing and care instructions (e.g. machine wash, do not bleach, iron) to the label.',
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
      prescribedDeclaration: 'Model / serial number',
      whyItMatters:
          'A model or serial number is needed to identify the exact product, support warranty and facilitate service/callbacks.',
      howToFix:
          'Ensure a model or serial number is printed on the product or its packaging.',
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
      prescribedDeclaration: 'Warranty / guarantee terms',
      whyItMatters:
          'Electronics usually carry a warranty; declaring the terms sets consumer expectations for coverage and repairs.',
      howToFix:
          'Declare the warranty or guarantee terms on the packaging.',
    ),
    ComplianceRule(
      id: 'CAT-ELC-03',
      declaration: 'Importer / Marketer Detail',
      description:
          'Importer / authorised representative details should be present.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'MEDIUM',
      prescribedDeclaration:
          'Importer / authorised representative name & address',
      whyItMatters:
          'For imported electronic goods the importer or authorised representative must be identified for accountability.',
      howToFix:
          'Ensure the importer or authorised representative details are printed on the package.',
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
      prescribedDeclaration:
          'Voltage / wattage / electrical rating',
      whyItMatters:
          'Electrical ratings prevent misuse and overloading, protecting the user from shocks and fire hazards.',
      howToFix:
          'Declare the voltage, wattage or electrical rating on the product or packaging.',
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
      prescribedDeclaration: 'Safety / certification mark',
      whyItMatters:
          'A recognised safety mark confirms the product meets applicable safety standards.',
      howToFix:
          'Display the applicable safety or certification mark on the product or packaging.',
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
      prescribedDeclaration: 'Warranty / guarantee terms',
      whyItMatters:
          'Declaring warranty terms informs consumers about coverage and repair rights.',
      howToFix:
          'Declare the warranty or guarantee terms on the packaging.',
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
      prescribedDeclaration: 'Full list of ingredients',
      whyItMatters:
          'Consumers need the full ingredient list to avoid allergens and make informed personal-care choices.',
      howToFix:
          'Print the complete list of ingredients on the product label.',
    ),
    ComplianceRule(
      id: 'CAT-COS-02',
      declaration: 'Manufacturing / Expiry Date',
      description:
          'Manufacture and expiry (or shelf-life) date should be declared.',
      legalReference:
          'Legal Metrology (Packaged Commodities) Rules, 2011',
      severity: 'HIGH',
      prescribedDeclaration: 'Manufacturing and/or expiry (shelf-life) date',
      whyItMatters:
          'Cosmetics degrade; manufacture and expiry dates tell the consumer when the product is safe to use.',
      howToFix:
          'Declare the manufacturing and/or expiry (shelf-life) date on the product.',
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
      prescribedDeclaration: 'Manufacturing license / regulatory authority',
      whyItMatters:
          'A valid manufacturing license indicates the item was made by an authorised, monitored facility.',
      howToFix:
          'Display the manufacturing license number or regulatory authority on the packaging.',
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
      prescribedDeclaration: 'Usage / handling instructions',
      whyItMatters:
          'Clear usage instructions prevent misuse of household chemicals and products.',
      howToFix:
          'Add clear usage or handling instructions to the packaging.',
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
      prescribedDeclaration: 'Caution / safety warnings',
      whyItMatters:
          'Safety warnings protect consumers from hazards such as poisoning, flammability or irritation.',
      howToFix:
          'Add the relevant caution and safety warnings to the packaging.',
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
      prescribedDeclaration: 'Batch / lot number',
      whyItMatters:
          'A batch or lot number enables traceability and targeted recalls if a defect is found.',
      howToFix:
          'Print a batch or lot number on the packaging.',
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