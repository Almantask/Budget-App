import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'state/budget_controller.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key, required this.controller});

  final BudgetController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        title: 'Šeimos biudžetas',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('lt'),
        supportedLocales: const [Locale('lt'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _StatusListener(child: HomeShell()),
      ),
    );
  }
}

class _StatusListener extends StatelessWidget {
  const _StatusListener({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetController>(
      builder: (context, controller, _) {
        final message = controller.statusMessage;
        if (message != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (controller.statusMessage == null) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
            controller.clearStatus();
          });
        }
        return child;
      },
    );
  }
}
