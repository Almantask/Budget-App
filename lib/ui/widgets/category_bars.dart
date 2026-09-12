import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/insight.dart';
import '../theme.dart';

class CategoryBars extends StatelessWidget {
  const CategoryBars({super.key, required this.rows});

  final List<CategorySpend> rows;

  @override
  Widget build(BuildContext context) {
    final visible = rows.where((r) => r.amount > 0).take(8).toList();
    final max = visible.fold<double>(0, (s, r) => r.amount > s ? r.amount : s);
    return Column(
      children: [
        for (final row in visible) _BarRow(row: row, max: max),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.row, required this.max});

  final CategorySpend row;
  final double max;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : row.amount / max;
    final color =
        row.optional > row.essential ? AppColors.optional : AppColors.seed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Categories.byId(row.categoryId).name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatEur(row.amount),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.track),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ratio.clamp(0.0, 1.0),
                      child: ColoredBox(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
