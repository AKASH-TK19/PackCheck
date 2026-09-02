import 'package:flutter/material.dart';

import '../models/product_category.dart';
import '../theme/app_theme.dart';

/// Mandatory "What are you checking?" product-category gate shown before any
/// image capture / upload.
///
/// The Continue button stays disabled until exactly one category is selected.
/// On selection the chosen [ProductCategoryInfo] is returned via
/// [Navigator.pop] so the caller can start the inspection with it.
class ProductCategoryScreen extends StatefulWidget {
  const ProductCategoryScreen({super.key});

  @override
  State<ProductCategoryScreen> createState() => _ProductCategoryScreenState();
}

class _ProductCategoryScreenState extends State<ProductCategoryScreen> {
  ProductCategoryInfo? _selected;

  void _select(ProductCategoryInfo category) {
    setState(() {
      _selected = category;
    });
  }

  void _continue() {
    final selected = _selected;
    if (selected == null) return;

    Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Scaffold(
      backgroundColor: PackCheckColors.background,
      appBar: AppBar(
        title: const Text('Product Category'),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What are you checking?',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: PackCheckColors.dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a product type and PackCheck will run the '
                      'compliance checks that apply to it.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.98,
                      ),
                      itemCount: ProductCategory.all.length,
                      itemBuilder: (context, index) {
                        final category = ProductCategory.all[index];
                        final isSelected =
                            selected?.label == category.label;

                        return _CategoryTile(
                          category: category,
                          selected: isSelected,
                          onTap: () => _select(category),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            _ContinueBar(enabled: selected != null, onContinue: _continue),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ProductCategoryInfo category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = category.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? baseColor.withValues(alpha: .08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? baseColor : Colors.grey.shade200,
          width: selected ? 2.2 : 1,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: baseColor.withValues(alpha: .25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            baseColor,
                            baseColor.withValues(alpha: .75),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        category.icon,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                    if (selected)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: baseColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  category.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: PackCheckColors.dark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  category.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback onContinue;

  const _ContinueBar({
    required this.enabled,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.maybePop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: enabled ? onContinue : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(enabled ? 'CONTINUE' : 'SELECT A CATEGORY'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
