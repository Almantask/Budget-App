import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/insight.dart';
import '../motion.dart';
import '../theme.dart';
import 'animated_number.dart';

class CategoryBars extends StatelessWidget {
  const CategoryBars({super.key, required this.rows});

  final List<CategorySpend> rows;

  @override
  Widget build(BuildContext context) {
    final visible = rows.where((r) => r.amount > 0).take(8).toList();
    final max = visible.fold<double>(0, (s, r) => r.amount > s ? r.amount : s);
    return Column(
      children: [
        for (var i = 0; i < visible.length; i++)
          _BarRow(row: visible[i], max: max, index: i),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.row,
    required this.max,
    required this.index,
  });

  final CategorySpend row;
  final double max;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : row.amount / max;
    final color =
        row.optional > row.essential ? AppColors.optional : AppColors.seed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Categories.byId(row.categoryId).name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedEur(
                value: row.amount,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: AppMotion.of(
              context,
              Duration(milliseconds: AppMotion.bars.inMilliseconds + index * 45),
            ),
            curve: Interval(
              (index * 0.07).clamp(0.0, 0.6),
              1,
              curve: AppMotion.easeOut,
            ),
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 9,
                  child: Stack(
                    children: [
                      const ColoredBox(
                        color: AppColors.track,
                        child: SizedBox.expand(),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: value.clamp(0.0, 1.0),
                          child: ColoredBox(
                            color: color,
                            child: const SizedBox.expand(),
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
    );
  }
}
