import 'package:flutter/material.dart';

import '../models/officer_session.dart';
import '../models/product_category.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'inspection_history_screen.dart';
import 'new_inspection_screen.dart';
import 'officer_login_screen.dart';
import 'product_category_screen.dart';
import 'product_listing_analysis_screen.dart';
import 'product_repository_screen.dart';
import 'requirement_coverage_screen.dart';
import 'violation_summary_screen.dart';

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
            'PackCheck',
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
                // Brand hero — communicates PackCheck at a glance.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: PackCheckColors.brandGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.fact_check_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'PACKCHECK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'AI-Powered Package Compliance Scanner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scan a pre-packaged product and check whether '
                        'required declarations are present.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Workflow strip.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _WorkflowStep(icon: Icons.camera_alt_outlined, label: 'Scan'),
                      _WorkflowArrow(),
                      _WorkflowStep(icon: Icons.psychology_outlined, label: 'Analyze'),
                      _WorkflowArrow(),
                      _WorkflowStep(icon: Icons.balance_outlined, label: 'Check'),
                      _WorkflowArrow(),
                      _WorkflowStep(icon: Icons.query_stats, label: 'Result'),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Main statistics.
                Row(
                  children: [
                    _statCard(
                      'Scans',
                      loading ? '...' : '$inspections',
                      Icons.fact_check_outlined,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Issues Found',
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

                const SizedBox(height: 20),

                // Primary action.
                SizedBox(
                  width: double.infinity,
                  height: 62,
                  child: FilledButton.icon(
                    onPressed: _openNewInspection,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text(
                      'START NEW SCAN',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'Compliance Overview',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: PackCheckColors.dark,
                  ),
                ),

                const SizedBox(height: 12),

                // Overall compliance health card.
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
                              color: PackCheckColors.primary,
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
                              'Scan Overview',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              loading
                                  ? 'Loading scan statistics...'
                                  : 'Compliant scans based on the current screening score.',
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

                const SizedBox(height: 22),

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

                _menuCard(
                  context,
                  Icons.storefront_outlined,
                  'Product Listing Analysis',
                  'Screen an online / e-commerce product listing',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ProductListingAnalysisScreen(),
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
// HOME WORKFLOW STRIP
// ============================================================

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: PackCheckColors.primaryTint,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: PackCheckColors.primary, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PackCheckColors.dark,
          ),
        ),
      ],
    );
  }
}

class _WorkflowArrow extends StatelessWidget {
  const _WorkflowArrow();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.arrow_forward,
      size: 16,
      color: Colors.grey.shade400,
    );
  }
}
