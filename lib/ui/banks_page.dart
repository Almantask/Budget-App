import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/bank.dart';
import '../models/connected_account.dart';
import '../models/person.dart';
import '../state/budget_controller.dart';

class BanksPage extends StatelessWidget {
  const BanksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BudgetController>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Kartą į dieną auto-sync'),
          subtitle: const Text(
            'Programa pati traukia Artea, Revolut, Swed ir Wise. Jei app uždaryta, OS pažadina kartą per parą.',
          ),
          value: controller.state.autoSyncEnabled,
          onChanged: controller.setAutoSync,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: controller.syncing
              ? null
              : () => controller.syncAll(triggeredBy: 'Rankinis sync'),
          icon: controller.syncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: const Text('Sinchronizuoti dabar'),
        ),
        const SizedBox(height: 16),
        for (final bank in BankId.values)
          _BankCard(
            bank: bank,
            account: controller.state.accounts
                .where((a) => a.bank == bank)
                .firstOrNull,
          ),
      ],
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.bank, required this.account});

  final BankId bank;
  final ConnectedAccount? account;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BudgetController>();
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final status = account?.status ?? AccountLinkStatus.disconnected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(bank.shortLabel[0])),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bank.label,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(_statusLabel(status)),
                    ],
                  ),
                ),
              ],
            ),
            if (account?.lastSyncedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Paskutinis sync: ${fmt.format(account!.lastSyncedAt!)}'),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: account?.personId ?? Person.meId,
              decoration: const InputDecoration(
                labelText: 'Sąskaitos savininkas',
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                  value: controller.state.household.me.id,
                  child: Text(controller.state.household.me.name),
                ),
                DropdownMenuItem(
                  value: controller.state.household.partner.id,
                  child: Text(controller.state.household.partner.name),
                ),
              ],
              onChanged: (v) {
                if (v != null) controller.assignAccountPerson(bank, v);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () async {
                    final uri = await controller.connectBank(
                      bank,
                      personId: account?.personId ?? Person.meId,
                    );
                    if (uri != null) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Text(status == AccountLinkStatus.disconnected
                      ? 'Susieti per Open Banking'
                      : 'Perjungti ryšį'),
                ),
                if (status == AccountLinkStatus.pending) ...[
                  if (account?.authorizationUrl != null)
                    OutlinedButton(
                      onPressed: () async {
                        await launchUrl(
                          Uri.parse(account!.authorizationUrl!),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: const Text('Atidaryti sutikimą'),
                    ),
                  OutlinedButton(
                    onPressed: () => _pasteCallback(context, bank),
                    child: const Text('Įklijuoti sutikimo nuorodą'),
                  ),
                ],
                OutlinedButton(
                  onPressed: () async {
                    final err = await controller.pickAndImportCsv(
                      bank: bank,
                      personId: account?.personId ?? Person.meId,
                    );
                    if (err != null && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(err)));
                    }
                  },
                  child: const Text('CSV importas'),
                ),
                if (controller.credentials.hasEnableBanking)
                  TextButton(
                    onPressed: () async {
                      final uri = Uri.parse('https://enablebanking.com/');
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    child: const Text('Enable Banking'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(AccountLinkStatus status) => switch (status) {
        AccountLinkStatus.disconnected => 'Nesusietas',
        AccountLinkStatus.pending => 'Laukia banko sutikimo',
        AccountLinkStatus.connected => 'Prijungtas (Enable Banking)',
        AccountLinkStatus.demo => 'Demo / CSV režimas',
      };
}

Future<void> _pasteCallback(BuildContext context, BankId bank) async {
  final field = TextEditingController();
  final submitted = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('${bank.label}: sutikimo nuoroda'),
        content: TextField(
          controller: field,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Enable Banking callback URL arba code',
            hintText: 'budgetapp://enable-banking/callback?code=…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Atšaukti'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text.trim()),
            child: const Text('Užbaigti'),
          ),
        ],
      );
    },
  );
  field.dispose();
  if (submitted == null || submitted.isEmpty || !context.mounted) return;
  await context.read<BudgetController>().completeBankLink(bank, submitted);
}
