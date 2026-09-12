import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:budget_app/models/geo.dart';
import 'package:budget_app/state/trip_controller.dart';
import 'package:budget_app/ui/trip_page.dart';

import 'trip_fakes.dart';

void main() {
  testWidgets('destination field plans from current location and lists stations',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const kaunas = PlaceSuggestion(
      label: 'Kaunas',
      subtitle: 'Kaunas, Lietuva',
      point: GeoPoint(lat: 54.8969, lon: 23.9260),
    );
    final routing = FakeTripRoutingService(places: [kaunas]);
    final controller = TripController(
      routing: routing,
      location: FakeLocationSource(),
    );

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
          home: Scaffold(body: TripPage(showMap: false)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Ieškoti degalinės'), findsNothing);
    expect(find.text('Maršrutas'), findsNothing);
    expect(find.text('Istorija'), findsNothing);
    expect(find.text('Apie'), findsNothing);
    expect(find.text('Kur važiuojate?'), findsOneWidget);
    expect(find.textContaining('Iš:'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Kaunas');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.text('Kaunas').last);
    await tester.pump();
    await tester.pump();

    expect(find.text('Savanorių pr. 174, Vilnius'), findsOneWidget);
    expect(find.text('7 min'), findsOneWidget);
    expect(find.text('maks. greičiu'), findsWidgets);
    expect(find.textContaining('Degalinės'), findsOneWidget);

    await tester.tap(find.byTooltip('Sutraukti'));
    await tester.pumpAndSettle();
    expect(find.text('Savanorių pr. 174, Vilnius'), findsNothing);
    expect(find.byTooltip('Išskleisti'), findsOneWidget);
  });
}
