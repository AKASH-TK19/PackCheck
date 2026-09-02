import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/compliance_rule.dart';
import 'models/product_category.dart';
import 'services/barcode_service.dart';
import 'services/compliance_engine.dart';
import 'services/database_service.dart';
import 'services/report_service.dart';
import 'services/readability_service.dart';
import 'screens/barcode_scanner_screen.dart';
import 'screens/product_category_screen.dart';
import 'services/ocr_service.dart';

void main() {
  runApp(const LMInspectApp());
}

class LMInspectApp extends StatelessWidget {
  const LMInspectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LM Inspect',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
      ),
      home: const OfficerLoginScreen(),
    );
  }
}

// ============================================================
// DEMO OFFICER SESSION
// ============================================================

class OfficerSession {
  static String? officerId;
  static String? role;

  static bool get isAdmin =>
      role == 'ADMIN';
}

// ============================================================
// OFFICER LOGIN
// ============================================================

class OfficerLoginScreen extends StatefulWidget {
  const OfficerLoginScreen({super.key});

  @override
  State<OfficerLoginScreen> createState() => _OfficerLoginScreenState();
}

class _OfficerLoginScreenState extends State<OfficerLoginScreen> {
  final officerIdController = TextEditingController(
      text: OfficerSession.officerId ?? '',
    );
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool loggingIn = false;

  @override
  void dispose() {
    officerIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final id = officerIdController.text.trim();
    final password = passwordController.text;

    if (id.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter Officer ID and password.')),
      );
      return;
    }

    setState(() => loggingIn = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    // Hackathon demo credentials only. Production deployment should use
    // departmental authentication / SSO and never hard-code credentials.
    final creds = <String, String>{
      'LM001': 'OFFICER',
      'ADM001': 'ADMIN',
    };

    final role = creds[id] == null
        ? null
        : (password == 'LM@1234' ? creds[id] : null);

    final valid = role != null;

    if (!mounted) return;

    if (!valid) {
      setState(() => loggingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid officer credentials.')),
      );
      return;
    }

    OfficerSession.officerId = id;
    OfficerSession.role = role;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.account_balance_outlined,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'LEGAL METROLOGY',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Officer Inspection System',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 35),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Authorised Officer Login',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: officerIdController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Officer ID',
                            hintText: 'Enter Officer ID',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          onSubmitted: (_) => login(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => obscurePassword = !obscurePassword);
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: loggingIn ? null : login,
                            icon: loggingIn
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              loggingIn ? 'AUTHENTICATING...' : 'OFFICER LOGIN',
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Authorised personnel only',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Hackathon prototype authentication',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DASHBOARD
// ============================================================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int inspections = 0;
  int violations = 0;
  int compliant = 0;
  int needsReview = 0;
  List<Map<String, dynamic>> recentInspections = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadStatistics();
  }

  Future<void> loadStatistics() async {
    try {
      final db = DatabaseService();
      final inspectionData = await db.getInspections();
      final inspectionCount = await db.getInspectionCount();
      final violationCount = await db.getViolationCount();

      int compliantCount = 0;
      int reviewCount = 0;

      for (final inspection in inspectionData) {
        final scoreValue = inspection['score'];
        final score = scoreValue is num ? scoreValue.toDouble() : 0.0;
        final violationValue = inspection['violationCount'];
        final violationCountForInspection =
            violationValue is num ? violationValue.toInt() : 0;

        if (violationCountForInspection > 0) {
          reviewCount++;
        } else if (score >= 80) {
          compliantCount++;
        } else {
          reviewCount++;
        }
      }

      final sorted = List<Map<String, dynamic>>.from(inspectionData);
      sorted.sort((a, b) {
        final da = DateTime.tryParse('${a['inspectionDate'] ?? ''}');
        final dbDate = DateTime.tryParse('${b['inspectionDate'] ?? ''}');
        if (da == null && dbDate == null) return 0;
        if (da == null) return 1;
        if (dbDate == null) return -1;
        return dbDate.compareTo(da);
      });

      if (!mounted) return;

      setState(() {
        inspections = inspectionCount;
        violations = violationCount;
        compliant = compliantCount;
        needsReview = reviewCount;
        recentInspections = sorted.take(5).toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    OfficerSession.officerId = null;

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const OfficerLoginScreen(),
      ),
      (route) => false,
    );
  }

  void _openNewInspection() async {
    // Mandatory product-category gate: the officer must choose a category
    // before they can capture or upload an image for inspection.
    final category = await Navigator.push<ProductCategoryInfo>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProductCategoryScreen(),
      ),
    );

    if (category == null) {
      // User backed out without selecting a category.
      return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewInspectionScreen(category: category),
      ),
    );

    await loadStatistics();
  }

  @override
  Widget build(BuildContext context) {
    if (OfficerSession.officerId == null) {
      return const OfficerLoginScreen();
    }

    final totalForPercent = inspections == 0 ? 1 : inspections;
    final compliantPercent = (compliant / totalForPercent).clamp(0.0, 1.0);

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _logout();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'LM Inspect',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'Officer account',
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Officer Account'),
                    content: Text(
                      'Signed in as ${OfficerSession.officerId ?? 'Officer'} '
                      '(${OfficerSession.role ?? 'OFFICER'})',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext, false),
                        child: const Text('CANCEL'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext, true),
                        child: const Text('LOG OUT'),
                      ),
                    ],
                  ),
                ).then((logout) {
                  if (logout == true && mounted) {
                    _logout();
                  }
                });
              },
              icon: const Icon(Icons.account_circle_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: loadStatistics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enforcement Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Legal Metrology Inspection System',
                  style: TextStyle(color: Colors.grey.shade600),
                ),

                const SizedBox(height: 20),

                // Overall inspection health card.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 82,
                        height: 82,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: loading ? null : compliantPercent,
                              strokeWidth: 8,
                            ),
                            if (!loading)
                              Text(
                                '${(compliantPercent * 100).round()}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Inspection Overview',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              loading
                                  ? 'Loading inspection statistics...'
                                  : 'Compliant inspections based on the current screening score.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Main statistics.
                Row(
                  children: [
                    _statCard(
                      'Inspections',
                      loading ? '...' : '$inspections',
                      Icons.fact_check_outlined,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Potential Issues',
                      loading ? '...' : '$violations',
                      Icons.warning_amber_rounded,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    _statCard(
                      'Compliant',
                      loading ? '...' : '$compliant',
                      Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Needs Review',
                      loading ? '...' : '$needsReview',
                      Icons.rate_review_outlined,
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 62,
                  child: FilledButton.icon(
                    onPressed: _openNewInspection,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text(
                      'START NEW INSPECTION',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                const Text(
                  'Recent Inspections',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (recentInspections.isEmpty)
                  _emptyDashboardCard()
                else
                  ...recentInspections.map(_recentInspectionCard),

                const SizedBox(height: 24),

                const Text(
                  'Enforcement Tools',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                _menuCard(
                  context,
                  Icons.history,
                  'Inspection History',
                  'View previous inspections and findings',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InspectionHistoryScreen(),
                      ),
                    );
                    await loadStatistics();
                  },
                ),

                _menuCard(
                  context,
                  Icons.inventory_2_outlined,
                  'Product Repository',
                  'Search previously scanned products',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProductRepositoryScreen(),
                      ),
                    );
                  },
                ),

                _menuCard(
                  context,
                  Icons.warning_amber_rounded,
                  'Violation Summary',
                  'Review detected non-compliances',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ViolationSummaryScreen(),
                      ),
                    );
                  },
                ),

                _menuCard(
                  context,
                  Icons.description_outlined,
                  'Reports',
                  'View and export inspection reports',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InspectionHistoryScreen(),
                      ),
                    );
                  },
                ),

                _menuCard(
                  context,
                  Icons.fact_check_outlined,
                  'SIH Requirement Coverage',
                  'Track implementation of every problem-statement requirement',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RequirementCoverageScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.indigo),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyDashboardCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 42),
          SizedBox(height: 8),
          Text(
            'No inspections recorded yet',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Start an inspection to populate the dashboard.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _recentInspectionCard(Map<String, dynamic> inspection) {
    final product =
        '${inspection['productName'] ?? 'Unknown Product'}'.trim();
    final scoreValue = inspection['score'];
    final score = scoreValue is num ? scoreValue.toDouble() : 0.0;
    final violationValue = inspection['violationCount'];
    final inspectionViolations =
        violationValue is num ? violationValue.toInt() : 0;
    final date = '${inspection['inspectionDate'] ?? ''}';

    final bool hasIssue = inspectionViolations > 0;
    final bool isCompliant = !hasIssue && score >= 80;

    final IconData icon = isCompliant
        ? Icons.check_circle
        : hasIssue
            ? Icons.warning_amber_rounded
            : Icons.help_outline;

    final String status = isCompliant
        ? 'COMPLIANT'
        : hasIssue
            ? 'POTENTIAL ISSUE'
            : 'NEEDS REVIEW';

    final Color iconColor = isCompliant
        ? Colors.green
        : hasIssue
            ? Colors.red
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withValues(alpha: .1),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  date.isEmpty ? 'Date not recorded' : date,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                status,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Score ${score.round()}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.withValues(alpha: .1),
          child: Icon(icon, color: Colors.indigo),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

// ============================================================
// SIH REQUIREMENT COVERAGE
// ============================================================

class RequirementCoverageScreen extends StatelessWidget {
  const RequirementCoverageScreen({super.key});

  static const List<_RequirementItem> _requirements = [
    _RequirementItem('Image upload / product scanning', _Status.done, 'Camera/gallery evidence capture is available.'),
    _RequirementItem('Product category selection gate', _Status.done, 'Mandatory category selection before capture/upload; category carried through inspection, result, report and repository.'),
    _RequirementItem('Multi-category compliance', _Status.done, 'Category-aware engine: universal LM rules for all categories, food-specific rules for food/beverage, category-specific rules for garments/electronics/electrical/cosmetics/household; advisory-only otherwise.'),
    _RequirementItem('Multiple package-side evidence', _Status.done, '2, 4, 6 or custom package sides; empty slots remain optional.'),
    _RequirementItem('QR / Barcode scanning', _Status.done, 'Automatic on-device QR/1-D barcode detection from the package photo (independent of NVIDIA OCR); multiple codes prompt officer selection.'),

    _RequirementItem('Automatic declaration extraction', _Status.inProgress, 'Local OCR is integrated; extraction accuracy is being improved.'),
    _RequirementItem('Product name', _Status.inProgress, 'Extracted from package evidence and officer-verifiable.'),
    _RequirementItem('Manufacturer / Packer / Importer', _Status.inProgress, 'Field exists; extraction needs stronger validation.'),
    _RequirementItem('Net quantity', _Status.inProgress, 'Field exists; extraction needs stronger validation.'),
    _RequirementItem('MRP', _Status.inProgress, 'Field exists; extraction needs stronger validation.'),
    _RequirementItem('Unit Sale Price', _Status.inProgress, 'Field exists; extraction needs stronger validation.'),
    _RequirementItem('Manufacture / Packing / Import date', _Status.inProgress, 'Field exists; extraction needs stronger validation.'),
    _RequirementItem('Consumer care details', _Status.inProgress, 'Field exists; extraction needs stronger validation.'),
    _RequirementItem('Other mandatory declarations', _Status.inProgress, 'Rule engine can be expanded as additional declarations are configured.'),

    _RequirementItem('Missing declaration detection', _Status.inProgress, 'Rule-based validation is present; coverage is being expanded.'),
    _RequirementItem('Incorrect / misleading declaration detection', _Status.inProgress, 'Requires additional validation rules and visual checks.'),
    _RequirementItem('MRP validation', _Status.inProgress, 'MRP extraction and validation are being improved.'),
    _RequirementItem('Placement analysis', _Status.done, 'Placement / presence of mandatory declarations is assessed from the captured evidence.'),
    _RequirementItem('Font-size analysis', _Status.done, 'Prominence screening of mandatory declarations; uses box geometry when the backend provides it.'),
    _RequirementItem('Readability analysis', _Status.done, 'Legibility screening of captured evidence text.'),

    _RequirementItem('Officer verification', _Status.done, 'Officer review screen allows correction before saving.'),
    _RequirementItem('Inspection status / preliminary assessment', _Status.done, 'Compliance screening and verification workflow are available.'),
    _RequirementItem('Violation summary', _Status.inProgress, 'Violation summary screen exists; coverage can be expanded.'),
    _RequirementItem('Evidence photographs', _Status.done, 'Inspection evidence can be captured and attached.'),
    _RequirementItem('Inspection history', _Status.done, 'Saved inspections can be reviewed.'),
    _RequirementItem('Product repository', _Status.done, 'Product repository screen is integrated.'),
    _RequirementItem('Search / retrieval', _Status.inProgress, 'Repository/history retrieval exists and can be expanded.'),

    _RequirementItem('PDF compliance report', _Status.done, 'PDF reporting is integrated.'),
    _RequirementItem('Editable report', _Status.done, 'Editable CSV export is available alongside the signed PDF report.'),
    _RequirementItem('Evidence attached to report', _Status.done, 'The primary evidence photograph is embedded in the report and stored with the record.'),

    _RequirementItem('Officer authentication', _Status.done, 'Officer login is implemented for the prototype.'),
    _RequirementItem('Role-based access', _Status.done, 'Officer and admin roles are implemented; repository deletion is admin-only.'),
    _RequirementItem('Secure production authentication', _Status.inProgress, 'Prototype authentication exists; departmental SSO/security is required for production.'),
    _RequirementItem('Enforcement dashboard', _Status.inProgress, 'Dashboard exists with inspection/violation statistics; monitoring features can be expanded.'),

    _RequirementItem('Product listing analysis', _Status.todo, 'Online/e-commerce listing analysis is not implemented yet.'),
    _RequirementItem('Technical architecture documentation', _Status.done, 'README and docs/ARCHITECTURE.md document the system and deployment framework.'),
  ];

  int get _doneCount =>
      _requirements.where((r) => r.status == _Status.done).length;

  int get _inProgressCount =>
      _requirements.where((r) => r.status == _Status.inProgress).length;

  int get _todoCount =>
      _requirements.where((r) => r.status == _Status.todo).length;

  int get _coveragePercent =>
      ((_doneCount / _requirements.length) * 100).round();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIH Requirement Coverage'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PACKCHECK',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'SIH Requirement Coverage',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_coveragePercent% of listed requirements are currently marked complete.',
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: _doneCount / _requirements.length,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  'Completed',
                  '$_doneCount',
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard(
                  'In Progress',
                  '$_inProgressCount',
                  Icons.pending_outlined,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard(
                  'Not Started',
                  '$_todoCount',
                  Icons.radio_button_unchecked,
                  Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text(
            'Requirement Checklist',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          ..._requirements.map(_requirementCard),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Note: This is a development tracker for the hackathon solution. '
              'It is not a legal certification of compliance with the Legal Metrology rules.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _requirementCard(_RequirementItem item) {
    final Color color;
    final IconData icon;
    final String label;

    switch (item.status) {
      case _Status.done:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'COMPLETED';
        break;
      case _Status.inProgress:
        color = Colors.orange;
        icon = Icons.pending;
        label = 'IN PROGRESS';
        break;
      case _Status.todo:
        color = Colors.grey;
        icon = Icons.radio_button_unchecked;
        label = 'NOT STARTED';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: .18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Status {
  done,
  inProgress,
  todo,
}

class _RequirementItem {
  final String title;
  final _Status status;
  final String description;

  const _RequirementItem(
    this.title,
    this.status,
    this.description,
  );
}

// ============================================================
// NEW INSPECTION
// ============================================================

class NewInspectionScreen extends StatefulWidget {
  final ProductCategoryInfo category;

  const NewInspectionScreen({
    super.key,
    required this.category,
  });

  @override
  State<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends State<NewInspectionScreen> {
  final ImagePicker _picker = ImagePicker();

  // The selected value is the number of physical package sides the
  // officer wants to document. Empty slots are optional.
  int packageSides = 2;
  bool customSides = false;
  int customSideCount = 8;

  final Map<int, XFile> sideImages = <int, XFile>{};
  final List<XFile> extraEvidence = <XFile>[];

  bool analyzing = false;
  String? scannedBarcode;

  // Set to "No barcode/QR detected" when an automatic image scan ran but found
  // nothing, so the result screen can distinguish an empty scan from one that
  // was never attempted.
  String? barcodeNote;

  int get totalSides => customSides ? customSideCount : packageSides;

  List<XFile> get allImages {
    final result = <XFile>[];

    for (var i = 0; i < totalSides; i++) {
      final image = sideImages[i];
      if (image != null) result.add(image);
    }

    result.addAll(extraEvidence);
    return result;
  }

  Future<void> _chooseImageForSide(int sideIndex) async {
    if (analyzing) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(
                sheetContext,
                ImageSource.camera,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(
                sheetContext,
                ImageSource.gallery,
              ),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 3000,
        maxHeight: 3000,
      );

      if (!mounted || image == null) return;

      setState(() {
        sideImages[sideIndex] = image;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not capture photo: $e')),
      );
    }
  }

  Future<void> _addExtraEvidence() async {
    if (analyzing) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Additional Photo'),
              onTap: () => Navigator.pop(
                sheetContext,
                ImageSource.camera,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose Additional Photo'),
              onTap: () => Navigator.pop(
                sheetContext,
                ImageSource.gallery,
              ),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 3000,
        maxHeight: 3000,
      );

      if (!mounted || image == null) return;

      setState(() {
        extraEvidence.add(image);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add photo: $e')),
      );
    }
  }

  Future<void> scanBarcode() async {
    if (analyzing) return;

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );

    if (!mounted || result == null || result.trim().isEmpty) {
      return;
    }

    setState(() {
      scannedBarcode = result.trim();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Product code detected: ${result.trim()}'),
      ),
    );
  }

  Future<void> analyze() async {
    final images = allImages;

    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Capture at least one package photo first.'),
        ),
      );
      return;
    }

    setState(() {
      analyzing = true;
    });

    try {
      // Send all captured evidence photos to the PackCheck NVIDIA backend.
      // The existing 2/4/6/custom-side workflow remains unchanged.
      // Empty package-side slots are not sent.
      final imageFiles = images
          .map((image) => File(image.path))
          .toList();

      final result = await OcrService.analyzeImages(imageFiles);

      if (!mounted) return;

      // Automatically detect QR / 1-D product barcodes from the captured
      // package photos, on-device and independent of the NVIDIA OCR backend.
      // This never fails the assessment: if nothing is detected the normal
      // OCR / compliance flow continues unchanged.
      await _autoDetectBarcode(imageFiles);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InspectionResultScreen(
            image: images.first,
            extractedText: result.text,
            ocrLines: result.lines,
            barcode: scannedBarcode,
            barcodeNote: barcodeNote,
            category: widget.category,
          ),
        ),
      );

      if (mounted) {
        setState(() {
          analyzing = false;
        });
      }
    } on OcrServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        analyzing = false;
      });

      await _handleOcrFallback(e, images);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        analyzing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis error: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Automatically inspects the captured package photos for QR codes and common
  // 1-D product barcodes. Runs on-device (mobile_scanner), fully independent of
  // NVIDIA OCR. Never throws: on any failure it degrades to "No barcode/QR
  // detected" and lets the assessment continue.
  //
  // - 0 codes  -> sets barcodeNote = 'No barcode/QR detected', scannedBarcode
  //               unchanged, and continues with the normal OCR flow.
  // - 1 code   -> auto-selects it as the product code.
  // - 2+ codes -> shows a picker of all unique values; the officer selects the
  //               relevant product code.
  Future<void> _autoDetectBarcode(List<File> imageFiles) async {
    final outcome = await BarcodeService.detectFromImages(imageFiles);

    if (!outcome.detected) {
      setState(() {
        barcodeNote = 'No barcode/QR detected';
      });
      return;
    }

    // Respect any value the officer already captured from a live-camera scan.
    final uniqueValues = <String>{...outcome.values};
    if (scannedBarcode != null && scannedBarcode!.isNotEmpty) {
      uniqueValues.add(scannedBarcode!);
    }

    if (uniqueValues.length == 1) {
      setState(() {
        scannedBarcode = uniqueValues.first;
        barcodeNote = null;
      });
      return;
    }

    displayBarcodePicker(outcome.values, outcome.types);
  }

  // Shows a bottom sheet listing every unique decoded value so the officer can
  // choose the relevant product code when several were detected.
  Future<void> displayBarcodePicker(
    List<String> values,
    Map<String, String> types,
  ) async {
    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Multiple codes detected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select the product code that is relevant to this inspection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final value in values)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.qr_code_2),
                            title: Text(
                              value,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(types[value] ?? 'CODE'),
                            onTap: () =>
                                Navigator.pop(sheetContext, value),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      if (selected != null && selected.isNotEmpty) {
        scannedBarcode = selected;
        barcodeNote = null;
      } else {
        // Officer dismissed the picker without choosing; keep an empty scan.
        barcodeNote = 'No barcode/QR detected';
      }
    });
  }

  // Allows the officer to continue the inspection offline by pasting the
  // label text when the OCR backend cannot be reached. This keeps the
  // compliance engine fully demoable during offline/lab demonstrations.
  Future<void> _handleOcrFallback(
    OcrServiceException error,
    List<XFile> images,
  ) async {
    if (!mounted) return;

    final controller = TextEditingController();

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.orange),
        title: const Text('OCR Backend Unavailable'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.message),
              const SizedBox(height: 16),
              const Text(
                'You can continue by entering the label text manually. '
                'The compliance and readability checks will still run on it.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'Paste or type the label text',
                  hintText:
                      'e.g. MRP: Rs 50\nNet Qty: 100 g\nManufactured by: ...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (!mounted) return;

    if (proceed != true) {
      return;
    }

    final manualText = controller.text.trim();

    if (manualText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No label text was entered.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionResultScreen(
          image: images.first,
          extractedText: manualText,
          ocrLines: const [],
          barcode: scannedBarcode,
          barcodeNote: barcodeNote,
          category: widget.category,
        ),
      ),
    );
  }

  Widget _preview(XFile image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: kIsWeb
          ? Image.network(
              image.path,
              fit: BoxFit.cover,
            )
          : Image.file(
              File(image.path),
              fit: BoxFit.cover,
            ),
    );
  }

  Widget _sideCard(int index) {
    final image = sideImages[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: image == null
              ? Colors.grey.shade300
              : Colors.indigo.withValues(alpha: .35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.indigo.withValues(alpha: .1),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Package Side ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                image == null ? 'Optional' : 'Captured',
                style: TextStyle(
                  color: image == null
                      ? Colors.grey.shade600
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (image != null) ...[
            SizedBox(
              height: 150,
              width: double.infinity,
              child: _preview(image),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _chooseImageForSide(index),
                  icon: Icon(
                    image == null
                        ? Icons.camera_alt_outlined
                        : Icons.refresh,
                  ),
                  label: Text(
                    image == null ? 'ADD PHOTO' : 'RETAKE',
                  ),
                ),
              ),
              if (image != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove photo',
                  onPressed: analyzing
                      ? null
                      : () {
                          setState(() {
                            sideImages.remove(index);
                          });
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectSideCount() async {
    if (analyzing) return;

    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                'How many package sides?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final count in [2, 4, 6])
              ListTile(
                leading: Icon(
                  count == totalSides
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: Colors.indigo,
                ),
                title: Text('$count Sides'),
                onTap: () => Navigator.pop(sheetContext, count),
              ),
            ListTile(
              leading: Icon(
                customSides
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: Colors.indigo,
              ),
              title: const Text('Other'),
              subtitle: const Text('Choose another number of sides'),
              onTap: () => Navigator.pop(sheetContext, -1),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == -1) {
      final controller = TextEditingController(
        text: customSides ? '$customSideCount' : '8',
      );

      final value = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Number of package sides'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Sides',
              hintText: 'Example: 8',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value != null && value >= 1 && value <= 20) {
                  Navigator.pop(dialogContext, value);
                }
              },
              child: const Text('USE'),
            ),
          ],
        ),
      );

      controller.dispose();

      if (!mounted || value == null) return;

      setState(() {
        customSides = true;
        customSideCount = value;
        sideImages.removeWhere((key, _) => key >= value);
      });
      return;
    }

    setState(() {
      customSides = false;
      packageSides = choice;
      sideImages.removeWhere((key, _) => key >= choice);
    });
  }

  @override
  Widget build(BuildContext context) {
    final capturedCount = allImages.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Inspection'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: widget.category.color.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.category.color,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.category.icon,
                      color: widget.category.color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SELECTED CATEGORY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.category.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A2B4C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PACKAGE EVIDENCE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Document the package sides',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Choose how many physical sides the package has. '
                      'You do not have to photograph every side.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.view_in_ar_outlined,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Package sides',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '2, 4, 6 or another number',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _selectSideCount,
                      child: Text('$totalSides'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Capture Evidence',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Every side is optional. Add only the photos that are '
                'useful or available during the inspection.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 14),

              for (var i = 0; i < totalSides; i++) _sideCard(i),

              const SizedBox(height: 4),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: analyzing ? null : _addExtraEvidence,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('ADD EXTRA EVIDENCE PHOTO'),
                ),
              ),

              if (extraEvidence.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Additional Evidence',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < extraEvidence.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(
                            width: 58,
                            height: 58,
                            child: _preview(extraEvidence[i]),
                          ),
                          title: Text(
                            'Additional photo ${i + 1}',
                          ),
                          trailing: IconButton(
                            onPressed: analyzing
                                ? null
                                : () {
                                    setState(() {
                                      extraEvidence.removeAt(i);
                                    });
                                  },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.indigo.withValues(alpha: .12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$capturedCount photo${capturedCount == 1 ? '' : 's'} '
                        'captured out of $totalSides package sides',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: analyzing ? null : scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(
                    scannedBarcode == null
                        ? 'SCAN QR / BARCODE'
                        : 'CODE: $scannedBarcode',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (analyzing)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Analysing captured package evidence...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Local OCR + Barcode + Legal Metrology validation',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton.icon(
                    onPressed: capturedCount == 0 ? null : analyze,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(
                      capturedCount == 0
                          ? 'ADD AT LEAST ONE PHOTO'
                          : 'RUN COMPLIANCE CHECK ($capturedCount PHOTOS)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              const Text(
                'Tip: For a chips packet, choose 2 sides and capture '
                'the front and/or back. For boxes or other packages, '
                'choose 4 or 6 sides as appropriate. Empty slots are '
                'allowed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// INSPECTION RESULT
// ============================================================

class InspectionResultScreen
    extends StatelessWidget {
  final XFile image;
  final String extractedText;
  final List<OcrLine> ocrLines;
  final String? barcode;
  final String? barcodeNote;
  final ProductCategoryInfo category;

  const InspectionResultScreen({
    super.key,
    required this.image,
    required this.extractedText,
    this.ocrLines = const [],
    this.barcode,
    this.barcodeNote,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final analysis =
        ComplianceEngine.analyzeFull(
      extractedText,
      category: category,
    );

    final product =
        analysis.product;

    final results =
        analysis.results;

    final readability = ReadabilityService.analyze(
      extractedText,
      lines: ocrLines,
    );

    final passed =
        results.where(
          (r) => r.detected,
        ).length;

    final score =
        ((passed / results.length) *
                100)
            .round();

    final violations =
        results.where(
          (r) =>
              !r.detected &&
              !r.rule.conditional,
        ).toList();

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Inspection Result'),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(18),
              decoration:
                  BoxDecoration(
                color: Colors.indigo,
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'LEGAL METROLOGY INSPECTION',
                    style: TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Automated Preliminary Assessment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Officer verification required before final record',
                    style: TextStyle(
                      color:
                          Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Evidence Photograph',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              height: 240,
              width: double.infinity,
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              clipBehavior:
                  Clip.antiAlias,
              child: kIsWeb
                  ? Image.network(
                      image.path,
                      fit:
                          BoxFit.contain,
                    )
                  : Image.file(
                      File(image.path),
                      fit:
                          BoxFit.contain,
                    ),
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(24),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Automated Screening',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$score%',
                    style:
                        const TextStyle(
                      fontSize: 52,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Colors.indigo,
                    ),
                  ),
                  Text(
                    violations.isEmpty
                        ? 'NO CONFIGURED VIOLATIONS DETECTED'
                        : '${violations.length} POTENTIAL VIOLATION(S)',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color:
                          violations.isEmpty
                              ? Colors.green
                              : Colors.red,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (category.isAdvisoryOnly) ...[
              _advisoryBanner(category),
              const SizedBox(height: 12),
            ],

            if (_categoryMismatchHint(extractedText, category) != null) ...[
              _mismatchBanner(_categoryMismatchHint(extractedText, category)!),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 25),

            const Text(
              'Extracted Product Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _buildField(
              'Product Category',
              category.label,
              category.icon,
            ),

            _buildField(
              'Product',
              product.productName,
              Icons.inventory_2_outlined,
            ),

            _buildField(
              'Barcode / QR Product ID',
              barcode ?? barcodeNote ?? 'Not scanned',
              Icons.qr_code_2_outlined,
            ),

            _buildField(
              'Maximum Retail Price',
              product.mrp,
              Icons.currency_rupee,
            ),

            _buildField(
              'Unit Sale Price',
              product.unitSalePrice,
              Icons.price_change_outlined,
            ),

            _buildField(
              'Net Quantity',
              product.netQuantity,
              Icons.scale_outlined,
            ),

            _buildField(
              'Manufacturer / Packer',
              product.manufacturer,
              Icons.factory_outlined,
            ),

            _buildField(
              'Country of Origin',
              product.countryOfOrigin,
              Icons.public,
            ),

            _buildField(
              'Manufacture / Packing Date',
              product.manufactureDate,
              Icons.calendar_month_outlined,
            ),

            _buildField(
              'Best Before / Use By',
              product.expiryDate,
              Icons.event_available_outlined,
            ),

            _buildField(
              'Consumer Care',
              product.consumerCare,
              Icons.support_agent_outlined,
            ),

            const SizedBox(height: 10),

            ExpansionTile(
              tilePadding:
                  EdgeInsets.zero,
              title: const Text(
                'Raw OCR Evidence',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.black87,
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                  child:
                      SelectableText(
                    extractedText.isEmpty
                        ? 'No text detected.'
                        : extractedText,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'Rule Validation',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...results.map(
              (result) =>
                  _ruleCard(result),
            ),

            const SizedBox(height: 25),

            const Text(
              'Potential Violations',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            if (violations.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.green
                          .withValues(alpha: .08),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color:
                          Colors.green,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No configured declaration violations detected.',
                      ),
                    ),
                  ],
                ),
              )
            else
              ...violations.map(
                (result) =>
                    _violationCard(result),
              ),

            const SizedBox(height: 25),

            const Text(
              'Font & Readability Check',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Assessment of placement, legibility and the prominence of '
              'mandatory declarations. Advisory only.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 12),

            _readabilityBlock(readability),

            const SizedBox(height: 25),

            // OFFICER VERIFICATION BUTTON
            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OfficerVerificationScreen(
                        image: image,
                        initialProduct:
                            product,
                        results: results,
                        extractedText:
                            extractedText,
                        barcode: barcode,
                        barcodeNote: barcodeNote,
                        category: category,

                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.verified_user_outlined,
                ),
                label: const Text(
                  'OFFICER VERIFICATION',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await ReportService.generateReport(
                            product: product,
                            results: results,
                            extractedText: extractedText,
                            imagePath: image.path,
                            barcode: barcode,
                            barcodeNote: barcodeNote,
                            category: category.label,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('PDF export failed: $e'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('EXPORT PDF'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await ReportService.generateEditableCsv(
                            product: product,
                            results: results,
                            extractedText: extractedText,
                            imagePath: image.path,
                            barcode: barcode,
                            barcodeNote: barcodeNote,
                            category: category.label,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('CSV export failed: $e'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('EXPORT CSV'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            const Text(
              'Automated screening is advisory. Final determination requires authorised officer verification.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    String value,
    IconData icon,
  ) {
    final missing =
        value == 'Not detected' ||
        value == 'Unknown Product';

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: missing
              ? Colors.orange
                  .withValues(alpha: .25)
              : Colors.grey
                  .withValues(alpha: .12),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: missing
                ? Colors.orange
                : Colors.indigo,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                    color: missing
                        ? Colors.orange
                            .shade800
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            missing
                ? Icons
                    .warning_amber_rounded
                : Icons.check_circle,
            size: 20,
            color: missing
                ? Colors.orange
                : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _ruleCard(
    ComplianceResult result,
  ) {
    final Color color;

    if (result.detected) {
      color = Colors.green;
    } else if (result.rule.conditional) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            result.detected
                ? Icons.check_circle
                : result.rule.conditional
                    ? Icons.help_outline
                    : Icons.cancel,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  result.rule.declaration,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  result.evidence,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _violationCard(
    ComplianceResult result,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color:
            Colors.red.withValues(alpha: .06),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color:
              Colors.red.withValues(alpha: .2),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  result.rule.declaration,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 6),
                Text(result.evidence),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readabilityBlock(
    ReadabilityAnalysis readability,
  ) {
    final Color sectionColor;

    if (readability.concernCount > 0) {
      sectionColor = Colors.orange;
    } else {
      sectionColor = Colors.green;
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: sectionColor
              .withValues(alpha: .25),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                readability.concernCount > 0
                    ? Icons.manage_search
                    : Icons.spellcheck,
                color: sectionColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  readability.concernCount > 0
                      ? '${readability.concernCount} item(s) '
                          'need verification'
                      : 'Overall readable and well placed',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (readability
              .placementFindings
              .isNotEmpty) ...[
            const Text(
              'Placement',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...readability
                .placementFindings
                .map(_readabilityFindingCard),
            const SizedBox(height: 10),
          ],

          if (readability
              .readabilityFindings
              .isNotEmpty) ...[
            const Text(
              'Readability',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...readability
                .readabilityFindings
                .map(_readabilityFindingCard),
            const SizedBox(height: 10),
          ],

          if (readability
              .fontSizeFindings
              .isNotEmpty) ...[
            const Text(
              'Font Size',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...readability
                .fontSizeFindings
                .map(_readabilityFindingCard),
          ],
        ],
      ),
    );
  }

  Widget _readabilityFindingCard(
    ReadabilityFinding finding,
  ) {
    final Color color;

    switch (finding.status) {
      case 'PASS':
        color = Colors.green;
        break;
      case 'POTENTIAL VIOLATION':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(bottom: 6),
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            color.withValues(alpha: .05),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: color
              .withValues(alpha: .18),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                finding.concern
                    ? Icons.info_outline
                    : Icons.check_circle_outline,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finding.title,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                finding.status,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            finding.explanation,
            style: TextStyle(
              fontSize: 12,
              color:
                  Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Shown when a non-food category is selected. The packaged-food / Legal
  // Metrology rules are not claimed to apply, so the result is advisory only
  // and never label the product as food-compliant.
  Widget _advisoryBanner(
    ProductCategoryInfo category,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.orange.withValues(alpha: .4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${category.label} — Advisory Only',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Category-specific compliance rules are not currently available. "
                  'Results are advisory and require officer verification.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This product is not labelled as food-compliant. Only '
                  'rules applicable to this category are evaluated.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // A possible mismatch between the selected category and the contents the
  // vision/OCR engine actually read. This is a hint only — the officer decides.
  String? _categoryMismatchHint(
    String text,
    ProductCategoryInfo category,
  ) {
    if (text.trim().isEmpty) return null;

    final lower = text.toLowerCase();

    if (category.isFood) {
      // Selected as food but the OCR mentions non-food / common household or
      // cosmetic terms.
      final nonFood = RegExp(
        r'\b(?:cosmetic|shampoo|soap|detergent|cleanser|lotion|paint|'
        r'toothpaste|deodorant|perfume|sanitizer|laundry|talc|cream)\b',
        caseSensitive: false,
      );

      if (nonFood.hasMatch(lower)) {
        return 'The selected category is Food/Legal Metrology, but the label '
            'mentions terms that are typically non-food '
            '(cosmetic/household). Please verify the product type.';
      }
    } else {
      // Selected as non-food but the OCR clearly reads packaged-food
      // declarations (best-before, FSSAI, ingredients, net quantity, MRP).
      final food = RegExp(
        r'\b(?:fssai|ingredients?|nutritional|best\s+before|use\s+by|'
        r'net\s+(?:quantity|wt|weight)|maximum\s+retail\s+price|'
        r'allergen|energy|protein|serving\s+size)\b',
        caseSensitive: false,
      );

      if (food.hasMatch(lower)) {
        return 'The selected category is non-food, but the label shows '
            'packaged-food declarations (e.g. best-before, FSSAI, '
            'ingredients, MRP). This may be a category mismatch.';
      }
    }

    return null;
  }

  Widget _mismatchBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.red.withValues(alpha: .4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Possible Category Mismatch',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// OFFICER VERIFICATION
// ============================================================

class OfficerVerificationScreen extends StatefulWidget {
  final XFile image;
  final ExtractedProductData initialProduct;
  final List<ComplianceResult> results;
  final String extractedText;
  final String? barcode;
  final String? barcodeNote;
  final ProductCategoryInfo category;

  const OfficerVerificationScreen({
    super.key,
    required this.image,
    required this.initialProduct,
    required this.results,
    required this.extractedText,
    this.barcode,
    this.barcodeNote,
    required this.category,
  });

  @override
  State<OfficerVerificationScreen> createState() =>
      _OfficerVerificationScreenState();
}

class _OfficerVerificationScreenState
    extends State<OfficerVerificationScreen> {
  late TextEditingController productController;
  late TextEditingController mrpController;
  late TextEditingController unitSalePriceController;
  late TextEditingController quantityController;
  late TextEditingController manufacturerController;
  late TextEditingController originController;
  late TextEditingController manufactureDateController;
  late TextEditingController expiryController;
  late TextEditingController consumerCareController;
  late TextEditingController officerIdController;
  late TextEditingController locationController;
  late TextEditingController remarksController;

  late final String inspectionId;
  late final DateTime inspectionTime;

  bool confirmed = false;

  @override
  void initState() {
    super.initState();

    inspectionTime = DateTime.now();
    inspectionId =
        'LM-${inspectionTime.year}'
        '${inspectionTime.month.toString().padLeft(2, '0')}'
        '${inspectionTime.day.toString().padLeft(2, '0')}-'
        '${inspectionTime.hour.toString().padLeft(2, '0')}'
        '${inspectionTime.minute.toString().padLeft(2, '0')}'
        '${inspectionTime.second.toString().padLeft(2, '0')}';

    productController =
        TextEditingController(text: widget.initialProduct.productName);
    mrpController =
        TextEditingController(text: widget.initialProduct.mrp);
    unitSalePriceController =
        TextEditingController(text: widget.initialProduct.unitSalePrice);
    quantityController =
        TextEditingController(text: widget.initialProduct.netQuantity);
    manufacturerController =
        TextEditingController(text: widget.initialProduct.manufacturer);
    originController =
        TextEditingController(text: widget.initialProduct.countryOfOrigin);
    manufactureDateController =
        TextEditingController(text: widget.initialProduct.manufactureDate);
    expiryController =
        TextEditingController(text: widget.initialProduct.expiryDate);
    consumerCareController =
        TextEditingController(text: widget.initialProduct.consumerCare);

    officerIdController = TextEditingController(
      text: OfficerSession.officerId ?? '',
    );
    locationController = TextEditingController();
    remarksController = TextEditingController();
  }

  @override
  void dispose() {
    productController.dispose();
    mrpController.dispose();
    unitSalePriceController.dispose();
    quantityController.dispose();
    manufacturerController.dispose();
    originController.dispose();
    manufactureDateController.dispose();
    expiryController.dispose();
    consumerCareController.dispose();
    officerIdController.dispose();
    locationController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> saveVerifiedInspection() async {
    if (!confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm officer verification first.')),
      );
      return;
    }
    if (officerIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Officer ID before verification.')),
      );
      return;
    }
    if (locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter inspection location.')),
      );
      return;
    }

    final violations = widget.results.where(
      (r) => !r.detected && !r.rule.conditional,
    ).length;
    final passed = widget.results.where((r) => r.detected).length;
    final score = widget.results.isEmpty
        ? 0
        : ((passed / widget.results.length) * 100).round();

    String evidenceHash;
    try {
      final bytes = await File(widget.image.path).readAsBytes();
      evidenceHash = sha256.convert(bytes).toString();
    } catch (_) {
      evidenceHash = '';
    }

        // Check the actual image fingerprint before saving.
    if (evidenceHash.isNotEmpty) {
      final duplicate = await DatabaseService().isDuplicateInspection(
        imagePath: widget.image.path,
        extractedText: widget.extractedText,
        evidenceKey: evidenceHash,
      );

      if (duplicate) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 52,
            ),
            title: const Text('Duplicate Inspection'),
            content: const Text(
              'This evidence appears to have already been submitted. ' 
              'The inspection was not saved again.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    final auditRecord = '''
AUDIT METADATA
Inspection ID: $inspectionId
Officer ID: ${officerIdController.text.trim()}
Product Category: ${widget.category.label}
Inspection Location: ${locationController.text.trim()}
Inspection Date/Time: ${inspectionTime.toIso8601String()}
Barcode / QR Product ID: ${widget.barcode ?? widget.barcodeNote ?? 'Not scanned'}
Verification Status: OFFICER VERIFIED
Evidence SHA-256: ${evidenceHash.isEmpty ? 'Unavailable' : evidenceHash}
Officer Remarks: ${remarksController.text.trim().isEmpty ? 'None' : remarksController.text.trim()}
''';

    await DatabaseService().saveInspection(
      productName: productController.text.trim().isEmpty
          ? 'Unknown Product'
          : productController.text.trim(),
      inspectionDate: inspectionTime.toIso8601String(),
      extractedText: '${widget.extractedText}\n\n$auditRecord',
      score: score,
      violationCount: violations,
      imagePath: widget.image.path,
      evidenceKey: evidenceHash.isEmpty ? null : evidenceHash,
      officerId: officerIdController.text.trim(),
      location: locationController.text.trim(),
      officerRemarks: remarksController.text.trim(),
      productCategory: widget.category.label,
      verified: true,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified, color: Colors.green, size: 50),
        title: const Text('Inspection Verified'),
        content: Text(
          'Inspection $inspectionId has been saved.\n\n'
          'Officer: ${officerIdController.text.trim()}\n'
          'Location: ${locationController.text.trim()}\n'
          'Evidence fingerprint: ${evidenceHash.isEmpty ? 'Unavailable' : 'SHA-256 recorded'}',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Verification'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    child: Icon(Icons.verified_user_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Officer Verification',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Review and confirm extracted evidence',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          inspectionId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Inspection Metadata',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            _metadataCard(
              Icons.badge_outlined,
              'Inspection ID',
              inspectionId,
            ),
            _metadataCard(
              Icons.schedule_outlined,
              'Inspection Date / Time',
              inspectionTime.toLocal().toString(),
            ),
            _metadataCard(
              Icons.qr_code_2_outlined,
              'Barcode / QR Product ID',
              widget.barcode ?? widget.barcodeNote ?? 'Not scanned',
            ),
            _editField(
              'Officer ID',
              officerIdController,
              Icons.badge,
            ),
            _editField(
              'Inspection Location',
              locationController,
              Icons.location_on_outlined,
            ),
            _editField(
              'Officer Remarks (Optional)',
              remarksController,
              Icons.notes_outlined,
            ),

            const SizedBox(height: 12),

            const Text(
              'Verify Extracted Information',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'OCR results can contain errors. Correct any field before confirming the inspection.',
              style: TextStyle(color: Colors.grey.shade700),
            ),

            const SizedBox(height: 18),

            _categoryReadOnlyCard(widget.category),

            const SizedBox(height: 14),

            if (widget.category.isAdvisoryOnly) ...[
              _verificationAdvisoryBanner(widget.category),
              const SizedBox(height: 14),
            ],

            _editField(
              'Product Name',
              productController,
              Icons.inventory_2_outlined,
            ),
            _editField(
              'Maximum Retail Price',
              mrpController,
              Icons.currency_rupee,
            ),
            _editField(
              'Unit Sale Price',
              unitSalePriceController,
              Icons.price_change_outlined,
            ),
            _editField(
              'Net Quantity',
              quantityController,
              Icons.scale_outlined,
            ),
            _editField(
              'Manufacturer / Packer',
              manufacturerController,
              Icons.factory_outlined,
            ),
            _editField(
              'Country of Origin',
              originController,
              Icons.public,
            ),
            _editField(
              'Manufacture / Packing Date',
              manufactureDateController,
              Icons.calendar_month_outlined,
            ),
            _editField(
              'Best Before / Use By',
              expiryController,
              Icons.event_available_outlined,
            ),
            _editField(
              'Consumer Care',
              consumerCareController,
              Icons.support_agent_outlined,
            ),

            const SizedBox(height: 15),

            const Text(
              'Automated Findings',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            ...widget.results.map(
              (result) => _verificationFinding(result),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: confirmed
                      ? Colors.green
                      : Colors.grey.shade300,
                ),
              ),
              child: CheckboxListTile(
                value: confirmed,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() {
                    confirmed = value ?? false;
                  });
                },
                title: const Text(
                  'I have reviewed the extracted information and automated findings.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'The final inspection record will be stored as officer-verified.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton.icon(
                onPressed: saveVerifiedInspection,
                icon: const Icon(Icons.verified_outlined),
                label: const Text(
                  'CONFIRM & SAVE INSPECTION',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final verifiedProduct = ExtractedProductData(
                    productName: productController.text.trim().isEmpty
                        ? 'Unknown Product'
                        : productController.text.trim(),
                    mrp: mrpController.text.trim(),
                    unitSalePrice: unitSalePriceController.text.trim(),
                    netQuantity: quantityController.text.trim(),
                    manufacturer: manufacturerController.text.trim(),
                    countryOfOrigin: originController.text.trim(),
                    manufactureDate:
                        manufactureDateController.text.trim(),
                    expiryDate: expiryController.text.trim(),
                    consumerCare: consumerCareController.text.trim(),
                  );

                  try {
                    await ReportService.generateReport(
                      product: verifiedProduct,
                      results: widget.results,
                      extractedText:
                          '${widget.extractedText}\n\n'
                          'AUDIT METADATA\n'
                          'Inspection ID: $inspectionId\n'
                          'Officer ID: ${officerIdController.text.trim().isEmpty ? 'Not entered' : officerIdController.text.trim()}\n'
                          'Product Category: ${widget.category.label}\n'
                          'Inspection Location: ${locationController.text.trim().isEmpty ? 'Not entered' : locationController.text.trim()}\n'
                          'Inspection Date/Time: ${inspectionTime.toIso8601String()}\n'
                          'Barcode / QR Product ID: ${widget.barcode ?? widget.barcodeNote ?? 'Not scanned'}\n'
                          'Verification Status: ${confirmed ? 'OFFICER VERIFIED' : 'PENDING OFFICER VERIFICATION'}\n'
                          'Officer Remarks: ${remarksController.text.trim().isEmpty ? 'None' : remarksController.text.trim()}',
                      imagePath: widget.image.path,
                      barcode: widget.barcode,
                      barcodeNote: widget.barcodeNote,
                      category: widget.category.label,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not generate report: $e'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text(
                  'GENERATE PDF REPORT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('BACK TO RESULTS'),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Automated screening is advisory. Final determination requires authorised officer verification.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metadataCard(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _categoryReadOnlyCard(ProductCategoryInfo category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: category.color),
      ),
      child: Row(
        children: [
          Icon(category.icon, color: category.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Category',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B4C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verificationAdvisoryBanner(ProductCategoryInfo category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.orange.withValues(alpha: .4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${category.label} — Advisory Only',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Category-specific compliance rules are not currently available. "
                  'Results are advisory and require officer verification. '
                  'This product is not labelled as food-compliant.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verificationFinding(ComplianceResult result) {
    final Color color;

    if (result.detected) {
      color = Colors.green;
    } else if (result.rule.conditional) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.detected
                ? Icons.check_circle
                : result.rule.conditional
                    ? Icons.help_outline
                    : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.rule.declaration,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  result.status,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.evidence,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INSPECTION HISTORY
// ============================================================

class InspectionHistoryScreen extends StatefulWidget {
  const InspectionHistoryScreen({
    super.key,
  });

  @override
  State<InspectionHistoryScreen> createState() =>
      _InspectionHistoryScreenState();
}

class _InspectionHistoryScreenState
    extends State<InspectionHistoryScreen> {
  List<Map<String, dynamic>> inspections = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadInspections();
  }

  Future<void> loadInspections() async {
    try {
      final data = await DatabaseService().getInspections();

      if (!mounted) return;

      setState(() {
        inspections = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> deleteInspection(int id) async {
    await DatabaseService().deleteInspection(id);
    await loadInspections();
  }

  void openInspectionDetails(Map<String, dynamic> inspection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionDetailsScreen(
          inspection: inspection,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection History'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(
                avatar: Icon(
                  OfficerSession.isAdmin
                      ? Icons.admin_panel_settings_outlined
                      : Icons.lock_outline,
                  size: 16,
                ),
                label: Text(
                  OfficerSession.isAdmin ? 'Admin' : 'Read-only',
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : inspections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 70,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'No inspections yet',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadInspections,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: inspections.length,
                    itemBuilder: (context, index) {
                      final inspection = inspections[index];

                      final id =
                          inspection['id'] is num
                              ? (inspection['id'] as num).toInt()
                              : index;

                      final scoreValue = inspection['score'];
                      final score = scoreValue is num
                          ? scoreValue.toDouble()
                          : double.tryParse(
                                  '${scoreValue ?? 0}',
                                ) ??
                              0;

                      final violationValue =
                          inspection['violationCount'];
                      final violations = violationValue is num
                          ? violationValue.toInt()
                          : int.tryParse(
                                  '${violationValue ?? 0}',
                                ) ??
                              0;

                      final product =
                          '${inspection['productName'] ?? 'Unknown Product'}';

                      final date =
                          '${inspection['inspectionDate'] ?? ''}';

                      return Dismissible(
                        key: ValueKey(id),
                        // Repository deletion is admin-only; officers browse
                        // the history in read-only mode.
                        direction: OfficerSession.isAdmin
                            ? DismissDirection.endToStart
                            : DismissDirection.none,
                        confirmDismiss: (_) async {
                          return showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete inspection?'),
                              content: const Text(
                                'Remove this inspection from the local repository?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context, false);
                                  },
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(context, true);
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) {
                          deleteInspection(id);
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => openInspectionDetails(inspection),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: score >= 80
                                      ? Colors.green.withValues(alpha: .1)
                                      : Colors.red.withValues(alpha: .1),
                                  child: Icon(
                                    score >= 80
                                        ? Icons.check
                                        : Icons.warning,
                                    color: score >= 80
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        date,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '$violations potential violation(s)',
                                        style: TextStyle(
                                          color: violations > 0
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to view full inspection',
                                        style: TextStyle(
                                          color: Colors.indigo.shade600,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${score.round()}%',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: score >= 80
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ============================================================
// INSPECTION DETAILS
// ============================================================

class InspectionDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> inspection;

  const InspectionDetailsScreen({
    super.key,
    required this.inspection,
  });

  String _value(String key, String fallback) {
    final value = inspection[key];
    if (value == null) return fallback;

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;

    final local = parsed.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  Future<void> _generateReport(BuildContext context) async {
    final extractedText = _value(
      'extractedText',
      'No extracted inspection data available.',
    );

    final barcode = _extractBarcode(extractedText);
    final barcodeNote = barcode.isEmpty
        ? 'No barcode/QR detected'
        : null;

    final categoryInfo =
        ProductCategory.byLabel(_value('productCategory', ''));
    final categoryLabel = categoryInfo?.label ?? _value('productCategory', '');

    try {
      final analysis = ComplianceEngine.analyzeFull(
        extractedText,
        category: categoryInfo,
      );

      await ReportService.generateReport(
        product: analysis.product,
        results: analysis.results,
        extractedText: extractedText,
        imagePath: _value('imagePath', ''),
        barcode: barcode,
        barcodeNote: barcodeNote,
        category: categoryLabel,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inspection PDF report generated.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate report: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _value('productName', 'Unknown Product');
    final score = _value('score', '0');
    final violations = _value('violationCount', '0');
    final date = _value('inspectionDate', 'Date not recorded');
    final officerId = _value('officerId', 'Not recorded');
    final location = _value('location', 'Not recorded');
    final verified = _value('verified', 'false');
    final remarks = _value('officerRemarks', 'None');
    final category = _value('productCategory', 'Not selected');
    final barcode = _extractBarcode(
      _value(
        'extractedText',
        '',
      ),
    );
    final imagePath = _value('imagePath', '');
    final extractedText = _value(
      'extractedText',
      'No extracted inspection data available.',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INSPECTION RECORD',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inspection date: ${_formatDate(date)}',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            _infoCard(
              'Inspection Summary',
              [
                _detailRow(
                  'Score',
                  '$score%',
                  Icons.analytics_outlined,
                ),
                _detailRow(
                  'Potential Violations',
                  violations,
                  Icons.warning_amber_rounded,
                ),
                _detailRow(
                  'Verification',
                  verified.toLowerCase() == 'true'
                      ? 'OFFICER VERIFIED'
                      : 'NOT VERIFIED',
                  Icons.verified_user_outlined,
                ),
                _detailRow(
                  'Officer ID',
                  officerId,
                  Icons.badge_outlined,
                ),
                _detailRow(
                  'Location',
                  location,
                  Icons.location_on_outlined,
                ),
                _detailRow(
                  'Barcode / QR',
                  barcode,
                  Icons.qr_code_2_outlined,
                ),
                _detailRow(
                  'Product Category',
                  category,
                  Icons.category_outlined,
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Text(
              'Inspection Evidence',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            if (imagePath.isNotEmpty && File(imagePath).existsSync())
              Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Evidence image is not available at the saved location.',
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            _infoCard(
              'Officer Remarks',
              [
                Text(
                  remarks,
                  style: const TextStyle(
                    height: 1.45,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              'Saved Inspection Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                extractedText,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _generateReport(context),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text(
                  'GENERATE / DOWNLOAD PDF REPORT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('BACK TO HISTORY'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractBarcode(String extractedText) {
    final lines = extractedText.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.toUpperCase().startsWith('BARCODE / QR PRODUCT ID:')) {
        final value = trimmed.substring(
          'BARCODE / QR PRODUCT ID:'.length,
        ).trim();

        if (value.isNotEmpty) return value;
      }

      if (trimmed.toUpperCase().startsWith('BARCODE:')) {
        final value = trimmed.substring('BARCODE:'.length).trim();

        if (value.isNotEmpty) return value;
      }
    }

    return 'Not recorded';
  }

  Widget _infoCard(
    String title,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: Colors.indigo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// PRODUCT REPOSITORY
// ============================================================

class ProductRepositoryScreen extends StatefulWidget {
  const ProductRepositoryScreen({super.key});

  @override
  State<ProductRepositoryScreen> createState() =>
      _ProductRepositoryScreenState();
}

class _ProductRepositoryScreenState
    extends State<ProductRepositoryScreen> {
  final TextEditingController searchController =
      TextEditingController();

  List<Map<String, dynamic>> allInspections = [];
  List<Map<String, dynamic>> filteredInspections = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProducts();
    searchController.addListener(filterProducts);
  }

  @override
  void dispose() {
    searchController.removeListener(filterProducts);
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadProducts() async {
    try {
      final data = await DatabaseService().getInspections();
      if (!mounted) return;

      setState(() {
        allInspections = data;
        filteredInspections = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  void filterProducts() {
    final query = searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        filteredInspections = allInspections;
      } else {
        filteredInspections = allInspections.where((item) {
          final product =
              (item['productName'] ?? '').toString().toLowerCase();
          final date =
              (item['inspectionDate'] ?? '').toString().toLowerCase();
          return product.contains(query) || date.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Repository'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search product or inspection date',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: searchController.clear,
                              icon: const Icon(Icons.clear),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: filteredInspections.isEmpty
                      ? const Center(
                          child: Text('No matching inspections found.'),
                        )
                      : RefreshIndicator(
                          onRefresh: loadProducts,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            itemCount: filteredInspections.length,
                            itemBuilder: (context, index) {
                              final item = filteredInspections[index];
                              final product =
                                  item['productName'] ?? 'Unknown Product';
                              final score = item['score'] ?? 0;
                              final violations =
                                  item['violationCount'] ?? 0;
                              final date =
                                  item['inspectionDate'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: violations > 0
                                          ? Colors.red.withValues(alpha: .1)
                                          : Colors.green.withValues(alpha: .1),
                                      child: Icon(
                                        violations > 0
                                            ? Icons.warning_amber_rounded
                                            : Icons.check_circle_outline,
                                        color: violations > 0
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.toString(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            date.toString(),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '$violations potential violation(s)',
                                            style: TextStyle(
                                              color: violations > 0
                                                  ? Colors.red
                                                  : Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '$score%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: score >= 80
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ============================================================
// VIOLATION SUMMARY
// ============================================================

class ViolationSummaryScreen extends StatefulWidget {
  const ViolationSummaryScreen({super.key});

  @override
  State<ViolationSummaryScreen> createState() =>
      _ViolationSummaryScreenState();
}

class _ViolationSummaryScreenState
    extends State<ViolationSummaryScreen> {
  List<Map<String, dynamic>> inspections = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final data = await DatabaseService().getInspections();
      if (!mounted) return;

      setState(() {
        inspections = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final withViolations = inspections.where((item) {
      final count = item['violationCount'] ?? 0;
      return count > 0;
    }).toList();

    final totalViolations = inspections.fold<int>(
      0,
      (sum, item) =>
          sum + ((item['violationCount'] ?? 0) as num).toInt(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Violation Summary'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.red.shade100,
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Potential Non-Compliances',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$totalViolations finding(s) across '
                                '${withViolations.length} inspection(s)',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Inspections Requiring Attention',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (withViolations.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No inspections with recorded potential '
                              'violations were found.',
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...withViolations.map((item) {
                      final product =
                          item['productName'] ?? 'Unknown Product';
                      final count = item['violationCount'] ?? 0;
                      final score = item['score'] ?? 0;
                      final date = item['inspectionDate'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: .15),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$count potential violation(s) • $score%',
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    date.toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
