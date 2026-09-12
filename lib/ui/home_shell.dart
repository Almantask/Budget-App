import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/budget_controller.dart';
import 'banks_page.dart';
import 'insights_page.dart';
import 'layout.dart';
import 'overview_page.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'transactions_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int index = 0;

  static const _pages = <Widget>[
    OverviewPage(),
    TransactionsPage(),
    InsightsPage(),
    BanksPage(),
    SettingsPage(),
  ];

  static const _titles = [
    'Apžvalga',
    'Operacijos',
    'Įžvalgos',
    'Bankai',
    'Nustatymai',
  ];

  static const _destinations = [
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
  ];

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
    final useRail = AppLayout.useNavigationRail(context);
    final compact = AppLayout.isLandscape(context) || AppLayout.isShort(context);

    final content = controller.loading
        ? const Center(child: CircularProgressIndicator())
        : IndexedStack(index: index, children: _pages);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: compact ? 48 : 56,
        title: Text(_titles[index]),
        actions: [
          _SyncButton(
            syncing: controller.syncing,
            onPressed: controller.syncing
                ? null
                : () => controller.syncAll(triggeredBy: 'Rankinis sync'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: useRail,
        child: useRail
            ? Row(
                children: [
                    _scrollableRail(AppLayout.isShort(context)),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => index = i),
              destinations: _destinations,
            ),
    );
  }

  Widget _scrollableRail(bool compact) {
    final rail = NavigationRail(
      selectedIndex: index,
      onDestinationSelected: (i) => setState(() => index = i),
      labelType:
          compact ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      minWidth: compact ? 56 : 80,
      groupAlignment: 0,
      destinations: [
        for (final d in _destinations)
          NavigationRailDestination(
            icon: d.icon,
            selectedIcon: d.selectedIcon,
            label: Text(d.label),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: rail),
          ),
        );
      },
    );
  }
}

class _SyncButton extends StatefulWidget {
  const _SyncButton({required this.syncing, required this.onPressed});

  final bool syncing;
  final VoidCallback? onPressed;

  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.syncing) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant _SyncButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncing && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.syncing && _spin.isAnimating) {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Sinchronizuoti',
      onPressed: widget.onPressed,
      icon: RotationTransition(
        turns: _spin,
        child: Icon(
          Icons.sync,
          color: widget.syncing ? AppColors.seed : null,
        ),
      ),
    );
  }
}
