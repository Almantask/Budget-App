import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'state/budget_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  await initializeDateFormatting('lt');
  final controller = BudgetController();
  await controller.load();
  await _listenForEnableBankingLinks(controller);
  runApp(BudgetApp(controller: controller));
}

Future<void> _listenForEnableBankingLinks(BudgetController controller) async {
  if (kIsWeb) {
    await controller.handleEnableBankingCallback(Uri.base);
    return;
  }
  try {
    final links = AppLinks();
    final initial = await links.getInitialLink();
    if (initial != null) {
      await controller.handleEnableBankingCallback(initial);
    }
    links.uriLinkStream.listen(controller.handleEnableBankingCallback);
  } catch (_) {
    // Tests and hosts without the plugin still run; paste-callback remains.
  }
}
