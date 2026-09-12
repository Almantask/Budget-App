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
import 'package:budget_app/ui/theme.dart';
import 'package:budget_app/ui/widgets/animated_number.dart';

class _NoopScheduler extends SyncScheduler {
  const _NoopScheduler();

  @override
  Future<void> registerDailySync() async {}

  @override
  Future<void> cancel() async {}
}

BudgetController _controller() {
  return BudgetController(
    store: BudgetStore(),
    scheduler: const _NoopScheduler(),
    now: () => DateTime(2026, 9, 12, 12),
  );
}

List<String> _overflowsFrom(FlutterErrorDetails details) {
  final text = details.toString();
  if (text.contains('overflowed') || text.contains('OVERFLOWING')) {
    return [text];
  }
  return const [];
}

Future<void> _pumpShell(WidgetTester tester, BudgetController controller) {
  return tester.pumpWidget(
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
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    await controller.load();
    await _pumpShell(tester, controller);
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
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('app loads demo household', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

  testWidgets('rotating to landscape keeps the overview usable', (tester) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      overflows.addAll(_overflowsFrom(details));
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _controller();
    await controller.load();
    await _pumpShell(tester, controller);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(NavigationBar), findsOneWidget);

    tester.view.physicalSize = const Size(800, 360);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Išlaidos'), findsOneWidget);
    expect(find.text('Išlaidos ir pajamos per laiką'), findsOneWidget);
    expect(overflows, isEmpty);
  });

  testWidgets('currency count-up reaches the formatted amount', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedEur(
            value: 1234.5,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(formatEur(1234.5)), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text(formatEur(1234.5)), findsOneWidget);
  });

  testWidgets('settings and banks describe Enable Banking', (tester) async {
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    await controller.load();
    await _pumpShell(tester, controller);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey<String>('settings-scroll')),
      const Offset(0, -5000),
    );
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
