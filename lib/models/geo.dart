class GeoPoint {
  const GeoPoint({required this.lat, required this.lon});

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.label,
    required this.point,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final GeoPoint point;
}

class FuelStation {
  const FuelStation({
    required this.id,
    required this.name,
    required this.address,
    required this.point,
    required this.etaAtMaxSpeed,
    required this.distanceMeters,
  });

  final String id;
  final String name;
  final String address;
  final GeoPoint point;
  final Duration etaAtMaxSpeed;
  final double distanceMeters;
}

class TripPlan {
  const TripPlan({
    required this.origin,
    required this.destination,
    required this.polyline,
    required this.totalEtaAtMaxSpeed,
    required this.totalDistanceMeters,
    required this.stations,
  });

  final GeoPoint origin;
  final PlaceSuggestion destination;
  final List<GeoPoint> polyline;
  final Duration totalEtaAtMaxSpeed;
  final double totalDistanceMeters;
  final List<FuelStation> stations;
}
