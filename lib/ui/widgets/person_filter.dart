import 'package:flutter/material.dart';

import '../../models/person.dart';

class PersonFilterBar extends StatelessWidget {
  const PersonFilterBar({
    super.key,
    required this.household,
    required this.value,
    required this.onChanged,
  });

  final Household household;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <(String, String)>[
      (Person.bothId, 'Abu'),
      (household.me.id, household.me.name),
      (household.partner.id, household.partner.name),
    ];
    return Wrap(
      spacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option.$2),
            selected: value == option.$1,
            onSelected: (_) => onChanged(option.$1),
          ),
      ],
    );
  }
}
