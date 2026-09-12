import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:budget_app/models/geo.dart';
import 'package:budget_app/services/location_source.dart';
import 'package:budget_app/services/trip_preferences.dart';
import 'package:budget_app/state/trip_controller.dart';

import 'trip_fakes.dart';

void main() {
  test('around me waits for GPS and plans only once', () async {
    final gate = Completer<LocationFix>();
    const fix = LocationFix(
      point: GeoPoint(lat: 54.9, lon: 23.9),
      isFallback: false,
    );
    final routing = FakeTripRoutingService();
    final controller = TripController(
      routing: routing,
      location: GatedLocationSource(gate, fix),
      preferencesStore: MemoryTripPreferencesStore(),
    );

    final originFuture = controller.ensureOrigin();
    await controller.selectAroundMe();
    expect(routing.aroundMeCalls, 0);
    expect(controller.aroundMeSelected, isTrue);

    gate.complete(fix);
    await originFuture;
    expect(routing.aroundMeCalls, 1);

    await controller.selectAroundMe();
    expect(routing.aroundMeCalls, 1);
  });
}
