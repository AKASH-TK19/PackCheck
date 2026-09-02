import 'package:flutter/material.dart';

import '../services/database_service.dart';

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
