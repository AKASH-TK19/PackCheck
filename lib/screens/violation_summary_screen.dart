import 'package:flutter/material.dart';

import '../services/database_service.dart';

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
