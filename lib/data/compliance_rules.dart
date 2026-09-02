import '../models/compliance_rule.dart';

class ComplianceRules {
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