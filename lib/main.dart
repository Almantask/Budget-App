import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'state/budget_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('lt');
  final controller = BudgetController();
  await controller.load();
  runApp(BudgetApp(controller: controller));
}
