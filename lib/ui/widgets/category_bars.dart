import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/insight.dart';
import '../theme.dart';

class CategoryBars extends StatelessWidget {
  const CategoryBars({super.key, required this.rows});

  final List<CategorySpend> rows;

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<double>(0, (s, r) => r.amount > s ? r.amount : s);
    return Column(
      children: [
        for (final row in rows.where((r) => r.amount > 0).take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(Categories.byId(row.categoryId).name)),
                    Text(
                      formatEur(row.amount),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final ratio = max == 0 ? 0.0 : row.amount / max;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 10,
                        width: constraints.maxWidth,
                        child: Stack(
                          children: [
                            const ColoredBox(
                              color: Color(0xFFE8E2D6),
                              child: SizedBox.expand(),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ColoredBox(
                                color: row.optional > row.essential
                                    ? const Color(0xFFC9783A)
                                    : const Color(0xFF0F6B5C),
                                child: SizedBox(
                                  width: constraints.maxWidth * ratio,
                                  height: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
