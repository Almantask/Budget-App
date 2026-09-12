import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/budget_controller.dart';
import 'banks_page.dart';
import 'insights_page.dart';
import 'overview_page.dart';
import 'settings_page.dart';
import 'transactions_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<BudgetController>().maybeDailySync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BudgetController>();
    final pages = const [
      OverviewPage(),
      TransactionsPage(),
      InsightsPage(),
      BanksPage(),
      SettingsPage(),
    ];
    final titles = const [
      'Apžvalga',
      'Operacijos',
      'Įžvalgos',
      'Bankai',
      'Nustatymai',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index]),
        actions: [
          IconButton(
            tooltip: 'Sinchronizuoti',
            onPressed: controller.syncing
                ? null
                : () => controller.syncAll(triggeredBy: 'Rankinis sync'),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: controller.loading
          ? const Center(child: CircularProgressIndicator())
          : pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Apžvalga',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Operacijos',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Įžvalgos',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Bankai',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Daugiau',
          ),
        ],
      ),
    );
  }
}
