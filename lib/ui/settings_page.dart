import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../banks/bank_connector.dart';
import '../models/budget_limit.dart';
import '../models/category.dart';
import '../state/budget_controller.dart';
import 'layout.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _me;
  late final TextEditingController _partner;
  late final TextEditingController _applicationId;
  late final TextEditingController _privateKey;
  late final TextEditingController _redirectUri;
  late final TextEditingController _wise;

  @override
  void initState() {
    super.initState();
    final controller = context.read<BudgetController>();
    _me = TextEditingController(text: controller.state.household.me.name);
    _partner =
        TextEditingController(text: controller.state.household.partner.name);
    _applicationId = TextEditingController(
      text: controller.credentials.enableBankingApplicationId ?? '',
    );
    _privateKey = TextEditingController(
      text: controller.credentials.enableBankingPrivateKey ?? '',
    );
    _redirectUri = TextEditingController(
      text: controller.credentials.enableBankingRedirectUri ??
          BankCredentials.defaultRedirectUri,
    );
    _wise = TextEditingController(
      text: controller.credentials.wiseApiToken ?? '',
    );
  }

  @override
  void dispose() {
    _me.dispose();
    _partner.dispose();
    _applicationId.dispose();
    _privateKey.dispose();
    _redirectUri.dispose();
    _wise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BudgetController>();
    return ListView(
      key: const PageStorageKey<String>('settings-scroll'),
      padding: AppLayout.pagePadding(context),
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
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => controller.renamePeople(
              me: _me.text.trim().isEmpty ? 'Aš' : _me.text.trim(),
              partner:
                  _partner.text.trim().isEmpty ? 'Žmona' : _partner.text.trim(),
            ),
            child: const Text('Išsaugoti vardus'),
          ),
        ),
        const SizedBox(height: 24),
        Text('Biudžeto ribos', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'Mėnesio limitai ir „Įspėti ties“ slenkstis. Būstas ir komunalinės gali turėti 100 %, kad vienkartinės sąskaitos nekeltų tempo įspėjimo.',
        ),
        const SizedBox(height: 12),
        _BudgetEditor(
          categoryId: 'overall',
          label: 'Visos išlaidos',
          budget: _limitFor(controller, 'overall'),
          onSave: controller.updateBudget,
        ),
        for (final category in Categories.spendable)
          _BudgetEditor(
            categoryId: category.id,
            label: category.name,
            budget: _limitFor(controller, category.id),
            onSave: controller.updateBudget,
          ),
        const SizedBox(height: 24),
        Text('Bankų raktai', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'Enable Banking (PSD2) sujungia Artea, Revolut, Swedbank ir Wise be slaptažodžių. Application ID ir RSA raktas lieka tik šiame įrenginyje. HTTPS Redirect URL turi sutapti su Allowed Redirect URLs valdymo skydelyje.',
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _applicationId,
          decoration: const InputDecoration(
            labelText: 'Enable Banking application ID',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _privateKey,
          maxLines: 6,
          minLines: 3,
          decoration: const InputDecoration(
            labelText: 'Enable Banking RSA private key (PEM)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _redirectUri,
          decoration: const InputDecoration(
            labelText: 'Enable Banking redirect URL',
            helperText:
                'Šį HTTPS adresą įrašykite Enable Banking Allowed Redirect URLs.',
          ),
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
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () => controller.saveCredentials(
              BankCredentials(
                enableBankingApplicationId: _applicationId.text.trim(),
                enableBankingPrivateKey: _privateKey.text.trim(),
                enableBankingRedirectUri: _redirectUri.text.trim(),
                wiseApiToken: _wise.text.trim(),
              ),
            ),
            child: const Text('Išsaugoti raktus'),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: controller.loadDemoData,
            child: const Text('Perkrauti demo duomenis'),
          ),
        ),
      ],
    );
  }

  BudgetLimit? _limitFor(BudgetController controller, String categoryId) {
    for (final budget in controller.state.budgets) {
      if (budget.categoryId == categoryId) return budget;
    }
    return null;
  }
}

class _BudgetEditor extends StatefulWidget {
  const _BudgetEditor({
    required this.categoryId,
    required this.label,
    required this.budget,
    required this.onSave,
  });

  final String categoryId;
  final String label;
  final BudgetLimit? budget;
  final Future<void> Function({
    required String categoryId,
    required double monthlyLimit,
    required double warnAt,
  }) onSave;

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  late final TextEditingController _limit;
  late double _warnAt;

  @override
  void initState() {
    super.initState();
    _limit = TextEditingController(
      text: widget.budget == null
          ? ''
          : widget.budget!.monthlyLimit.toStringAsFixed(0),
    );
    _warnAt = widget.budget?.warnAt ?? 0.8;
  }

  @override
  void didUpdateWidget(covariant _BudgetEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.budget?.monthlyLimit != widget.budget?.monthlyLimit &&
        !_limit.text.contains('.')) {
      _limit.text = widget.budget == null
          ? ''
          : widget.budget!.monthlyLimit.toStringAsFixed(0);
    }
    if (oldWidget.budget?.warnAt != widget.budget?.warnAt) {
      _warnAt = widget.budget?.warnAt ?? _warnAt;
    }
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
            TextField(
              controller: _limit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Mėnesio limito €',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Text('Įspėti ties ${(_warnAt * 100).round()}%'),
            Slider(
              min: 0.5,
              max: 1,
              divisions: 10,
              value: _warnAt,
              label: '${(_warnAt * 100).round()}%',
              onChanged: (value) => setState(() => _warnAt = value),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  final parsed = double.tryParse(
                        _limit.text.trim().replaceAll(',', '.'),
                      ) ??
                      0;
                  widget.onSave(
                    categoryId: widget.categoryId,
                    monthlyLimit: parsed,
                    warnAt: _warnAt,
                  );
                },
                child: const Text('Išsaugoti'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
