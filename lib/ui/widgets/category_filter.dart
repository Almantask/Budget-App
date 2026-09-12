import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/spend_tag.dart';
import 'chip_row.dart';

class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    super.key,
    required this.categoryId,
    required this.tag,
    required this.onCategory,
    required this.onTag,
  });

  final String? categoryId;
  final SpendTag? tag;
  final ValueChanged<String?> onCategory;
  final ValueChanged<SpendTag?> onTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: categoryId ?? '',
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Kategorija',
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('Visos kategorijos')),
            for (final c in Categories.all)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: (v) => onCategory(v == null || v.isEmpty ? null : v),
        ),
        const SizedBox(height: 10),
        ChipRow(
          children: [
            ChoiceChip(
              label: const Text('Visos žymos'),
              selected: tag == null,
              onSelected: (_) => onTag(null),
            ),
            ChoiceChip(
              label: Text(SpendTag.essential.label),
              selected: tag == SpendTag.essential,
              onSelected: (_) => onTag(SpendTag.essential),
            ),
            ChoiceChip(
              label: Text(SpendTag.optional.label),
              selected: tag == SpendTag.optional,
              onSelected: (_) => onTag(SpendTag.optional),
            ),
          ],
        ),
      ],
    );
  }
}
