import 'package:flutter/material.dart';

import '../models/officer_session.dart';
import '../services/database_service.dart';
import 'inspection_details_screen.dart';

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
