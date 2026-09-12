import 'package:flutter/material.dart';

import '../../models/period.dart';

class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PeriodKind value;
  final ValueChanged<PeriodKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in PeriodKind.values)
          ChoiceChip(
            label: Text(kind.label),
            selected: value == kind,
            onSelected: (_) => onChanged(kind),
          ),
      ],
    );
  }
}
