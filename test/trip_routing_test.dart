import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:budget_app/models/geo.dart';
import 'package:budget_app/services/trip_routing.dart';

void main() {
  const origin = GeoPoint(lat: 54.6872, lon: 25.2797);
  const destPoint = GeoPoint(lat: 54.8969, lon: 23.9260);
  const destination = PlaceSuggestion(
    label: 'Kaunas',
    subtitle: 'Kaunas, Lietuva',
    point: destPoint,
  );

  test('searchPlaces maps Nominatim results', () async {
    final service = TripRoutingService(
      httpClient: MockClient((request) async {
        expect(request.url.host, 'nominatim.openstreetmap.org');
        expect(request.headers['User-Agent'], TripRoutingService.userAgent);
        return http.Response(
          jsonEncode([
            {
              'lat': '54.8969',
              'lon': '23.9260',
              'name': 'Kaunas',
              'display_name': 'Kaunas, Lietuva',
            }
          ]),
          200,
        );
      }),
    );

    final results = await service.searchPlaces('Kaunas', near: origin);
    expect(results, hasLength(1));
    expect(results.first.label, 'Kaunas');
    expect(results.first.point.lat, closeTo(54.8969, 0.0001));
  });

  test('planTrip attaches address and max-speed ETA from OSRM table', () async {
    final service = TripRoutingService(
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/route/v1/driving')) {
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'duration': 5400,
                  'distance': 100000,
                  'geometry': {
                    'coordinates': [
                      [origin.lon, origin.lat],
                      [25.28, 54.69],
                      [destPoint.lon, destPoint.lat],
                    ],
                  },
                }
              ],
            }),
            200,
          );
        }
        if (request.url.host.contains('overpass')) {
          return http.Response(
          jsonEncode({
            'elements': [
              {
                'type': 'node',
                'id': 11,
                'lat': 54.69,
                'lon': 25.28,
                'tags': {
                  'amenity': 'fuel',
                  'brand': 'Neste',
                  'addr:street': 'Ukmergės g.',
                  'addr:housenumber': '240',
                  'addr:city': 'Vilnius',
                },
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
        }
        if (path.contains('/table/v1/driving')) {
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'durations': [
                [0, 420],
              ],
            }),
            200,
          );
        }
        return http.Response('unexpected ${request.url}', 404);
      }),
    );

    final plan = await service.planTrip(origin: origin, destination: destination);
    expect(plan.stations, hasLength(1));
    expect(plan.stations.first.name, 'Neste');
    expect(plan.stations.first.address, 'Ukmergės g. 240, Vilnius');
    expect(plan.stations.first.etaAtMaxSpeed, const Duration(seconds: 420));
    expect(plan.totalEtaAtMaxSpeed, const Duration(seconds: 5400));
  });
}
