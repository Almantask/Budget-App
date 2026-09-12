import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../banks/bank_connector.dart';
import '../state/budget_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _me;
  late final TextEditingController _partner;
  late final TextEditingController _secretId;
  late final TextEditingController _secretKey;
  late final TextEditingController _wise;

  @override
  void initState() {
    super.initState();
    final controller = context.read<BudgetController>();
    _me = TextEditingController(text: controller.state.household.me.name);
    _partner =
        TextEditingController(text: controller.state.household.partner.name);
    _secretId = TextEditingController(
      text: controller.credentials.gocardlessSecretId ?? '',
    );
    _secretKey = TextEditingController(
      text: controller.credentials.gocardlessSecretKey ?? '',
    );
    _wise = TextEditingController(
      text: controller.credentials.wiseApiToken ?? '',
    );
  }

  @override
  void dispose() {
    _me.dispose();
    _partner.dispose();
    _secretId.dispose();
    _secretKey.dispose();
    _wise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BudgetController>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text('Šeima', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _me,
          decoration: const InputDecoration(labelText: 'Pirmas žmogus'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _partner,
          decoration: const InputDecoration(labelText: 'Antras žmogus / žmona'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => controller.renamePeople(
            me: _me.text.trim().isEmpty ? 'Aš' : _me.text.trim(),
            partner:
                _partner.text.trim().isEmpty ? 'Žmona' : _partner.text.trim(),
          ),
          child: const Text('Išsaugoti vardus'),
        ),
        const SizedBox(height: 24),
        Text('Bankų raktai', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'GoCardless Bank Account Data (PSD2) sujungia Artea, Revolut, Swedbank ir Wise be slaptažodžių. Raktai lieka tik šiame įrenginyje.',
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _secretId,
          decoration: const InputDecoration(labelText: 'GoCardless secret_id'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _secretKey,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'GoCardless secret_key'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _wise,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Wise API token (nebūtina)',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => controller.saveCredentials(
            BankCredentials(
              gocardlessSecretId: _secretId.text.trim(),
              gocardlessSecretKey: _secretKey.text.trim(),
              wiseApiToken: _wise.text.trim(),
            ),
          ),
          child: const Text('Išsaugoti raktus'),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: controller.loadDemoData,
          child: const Text('Perkrauti demo duomenis'),
        ),
      ],
    );
  }
}
