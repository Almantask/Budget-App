import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_app/app.dart';
import 'package:budget_app/banks/sync_scheduler.dart';
import 'package:budget_app/data/budget_store.dart';
import 'package:budget_app/models/person.dart';
import 'package:budget_app/state/budget_controller.dart';
import 'package:budget_app/ui/home_shell.dart';

class _NoopScheduler extends SyncScheduler {
  const _NoopScheduler();

  @override
  Future<void> registerDailySync() async {}

  @override
  Future<void> cancel() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await initializeDateFormatting('lt');
  });

  testWidgets('overview defaults to both people and shows period chips',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = BudgetController(
      store: BudgetStore(),
      scheduler: const _NoopScheduler(),
      now: () => DateTime(2026, 9, 12, 12),
    );
    await controller.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(
          locale: Locale('lt'),
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('lt')],
          home: HomeShell(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.filters.personId, Person.bothId);
    expect(find.text('Abu'), findsWidgets);
    expect(find.text('Savaitė'), findsOneWidget);
    expect(find.text('Mėnuo'), findsOneWidget);
    expect(find.text('Metai'), findsOneWidget);
    expect(find.text('Visas laikotarpis'), findsOneWidget);
    expect(find.text('Išlaidos'), findsOneWidget);
    expect(find.text('Būtina vs nebūtina'), findsOneWidget);
    expect(find.text('Išlaidos ir pajamos per laiką'), findsOneWidget);
  });

  testWidgets('app loads demo household', (tester) async {
    final controller = BudgetController(
      scheduler: const _NoopScheduler(),
      now: () => DateTime(2026, 9, 12, 12),
    );
    await controller.load();
    await tester.pumpWidget(BudgetApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.state.transactions, isNotEmpty);
    expect(find.text('Apžvalga'), findsWidgets);
    await tester.tap(find.text('Įžvalgos').last);
    await tester.pumpAndSettle();
    expect(find.text('Taupymo tikslas'), findsOneWidget);
    expect(find.text('Mėnesio iššūkis'), findsOneWidget);
  });

  testWidgets('settings and banks describe Enable Banking', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = BudgetController(
      store: BudgetStore(),
      scheduler: const _NoopScheduler(),
      now: () => DateTime(2026, 9, 12, 12),
    );
    await controller.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(
          locale: Locale('lt'),
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('lt')],
          home: HomeShell(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -2400));
    await tester.pumpAndSettle();
    expect(find.text('Enable Banking application ID'), findsOneWidget);
    expect(find.text('Enable Banking RSA private key (PEM)'), findsOneWidget);
    expect(find.text('GoCardless secret_id'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Bankai'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kartą į dieną auto-sync'), findsOneWidget);
    expect(find.text('Perjungti ryšį'), findsWidgets);
    expect(find.text('GoCardless'), findsNothing);
  });
}
