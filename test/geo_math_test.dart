import 'package:flutter_test/flutter_test.dart';

import 'package:budget_app/models/geo.dart';
import 'package:budget_app/services/geo_math.dart';

void main() {
  test('formats max-speed ETA in Lithuanian', () {
    expect(formatMaxSpeedEta(const Duration(seconds: 40)), 'mažiau nei 1 min');
    expect(formatMaxSpeedEta(const Duration(minutes: 7)), '7 min');
    expect(formatMaxSpeedEta(const Duration(hours: 1)), '1 val.');
    expect(formatMaxSpeedEta(const Duration(hours: 1, minutes: 12)), '1 val. 12 min');
  });

  test('builds a concrete station address from OSM tags', () {
    expect(
      stationAddressFromTags({
        'addr:street': 'Savanorių pr.',
        'addr:housenumber': '174',
        'addr:city': 'Vilnius',
      }),
      'Savanorių pr. 174, Vilnius',
    );
    expect(
      stationAddressFromTags(
        const {},
        reverseGeocoded: 'Ukmergės g. 240, Vilnius',
      ),
      'Ukmergės g. 240, Vilnius',
    );
    expect(stationNameFromTags({'brand': 'Viada'}), 'Viada');
  });

  test('eta prefers routed duration and falls back to 130 km/h', () {
    expect(
      etaAtMaxSpeed(
        distanceMeters: 10000,
        routedDuration: const Duration(minutes: 8),
      ),
      const Duration(minutes: 8),
    );
    final fallback = etaAtMaxSpeed(distanceMeters: 130000);
    expect(fallback.inMinutes, 60);
  });

  test('samples polyline and measures distance to the line', () {
    const a = GeoPoint(lat: 54.68, lon: 25.27);
    const b = GeoPoint(lat: 54.70, lon: 25.29);
    const c = GeoPoint(lat: 54.72, lon: 25.31);
    final line = [a, b, c];
    expect(samplePolyline(line, maxPoints: 2), [a, c]);
    expect(distanceToPolylineMeters(b, line), lessThan(1));
    expect(distanceAlongPolylineMeters(b, line), greaterThan(0));
    expect(haversineMeters(a, a), 0);
  });
}
