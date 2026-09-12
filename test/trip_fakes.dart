import 'dart:async';

import 'package:budget_app/models/geo.dart';
import 'package:budget_app/services/location_source.dart';
import 'package:budget_app/services/trip_routing.dart';

class FakeLocationSource implements LocationSource {
  FakeLocationSource({
    this.fix = const LocationFix(
      point: GeoPoint(lat: 54.687157, lon: 25.279652),
      isFallback: false,
    ),
  });

  final LocationFix fix;

  @override
  Future<LocationFix> currentOrDefault() async => fix;
}

class GatedLocationSource implements LocationSource {
  GatedLocationSource(this.gate, this.fix);

  final Completer<LocationFix> gate;
  final LocationFix fix;

  @override
  Future<LocationFix> currentOrDefault() => gate.future.then((_) => fix);
}

class FakeTripRoutingService extends TripRoutingService {
  FakeTripRoutingService({
    this.places = const [],
    this.reverse = 'Gedimino pr. 1, Vilnius',
    this.plan,
    this.searchError,
    this.planError,
  });

  final List<PlaceSuggestion> places;
  final String? reverse;
  final TripPlan? plan;
  final String? searchError;
  final String? planError;
  final List<String> searched = [];
  final List<PlaceSuggestion> selected = [];

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    GeoPoint? near,
  }) async {
    searched.add(query);
    if (searchError != null) throw TripRoutingException(searchError!);
    return places;
  }

  @override
  Future<String?> reverseGeocode(GeoPoint point) async => reverse;

  @override
  Future<TripPlan> planTrip({
    required GeoPoint origin,
    required PlaceSuggestion destination,
  }) async {
    selected.add(destination);
    if (planError != null) throw TripRoutingException(planError!);
    return plan ??
        TripPlan(
          origin: origin,
          destination: destination,
          polyline: [origin, destination.point],
          totalEtaAtMaxSpeed: const Duration(minutes: 18),
          totalDistanceMeters: 12000,
          stations: [
            FuelStation(
              id: 'n-1',
              name: 'Circle K',
              address: 'Savanorių pr. 174, Vilnius',
              point: GeoPoint(
                lat: (origin.lat + destination.point.lat) / 2,
                lon: (origin.lon + destination.point.lon) / 2,
              ),
              etaAtMaxSpeed: const Duration(minutes: 7),
              distanceMeters: 4200,
            ),
          ],
        );
  }

  int aroundMeCalls = 0;

  @override
  Future<TripPlan> planAroundMe(GeoPoint origin) async {
    aroundMeCalls += 1;
    if (planError != null) throw TripRoutingException(planError!);
    return TripPlan(
      origin: origin,
      destination: PlaceSuggestion.aroundMe(origin),
      polyline: const [],
      totalEtaAtMaxSpeed: Duration.zero,
      totalDistanceMeters: 0,
      aroundMe: true,
      stations: [
        FuelStation(
          id: 'n-near',
          name: 'Viada',
          address: 'Geležinio Vilko g. 2, Vilnius',
          point: origin,
          etaAtMaxSpeed: const Duration(minutes: 3),
          distanceMeters: 900,
        ),
      ],
    );
  }
}
