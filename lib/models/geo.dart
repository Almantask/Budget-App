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

enum FuelKind {
  petrol95('A95'),
  petrol98('A98'),
  diesel('Dyzelinas'),
  lpg('Dujos');

  const FuelKind(this.label);
  final String label;
}

class TripPreferences {
  const TripPreferences({
    this.litersPer100km = 7.0,
    this.fuel = FuelKind.petrol95,
  });

  final double litersPer100km;
  final FuelKind fuel;

  TripPreferences copyWith({double? litersPer100km, FuelKind? fuel}) {
    return TripPreferences(
      litersPer100km: litersPer100km ?? this.litersPer100km,
      fuel: fuel ?? this.fuel,
    );
  }
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

  bool get isAroundMe => label == aroundMeLabel;

  static const aroundMeLabel = 'Aplink mane';

  factory PlaceSuggestion.aroundMe(GeoPoint origin) {
    return PlaceSuggestion(
      label: aroundMeLabel,
      subtitle: 'Degalinės netoliese',
      point: origin,
    );
  }
}

class FuelStation {
  const FuelStation({
    required this.id,
    required this.name,
    required this.address,
    required this.point,
    required this.etaAtMaxSpeed,
    required this.distanceMeters,
    this.fuels = const {},
  });

  final String id;
  final String name;
  final String address;
  final GeoPoint point;
  final Duration etaAtMaxSpeed;
  final double distanceMeters;
  final Set<FuelKind> fuels;

  bool offers(FuelKind kind) => fuels.isEmpty || fuels.contains(kind);
}

class TripPlan {
  const TripPlan({
    required this.origin,
    required this.destination,
    required this.polyline,
    required this.totalEtaAtMaxSpeed,
    required this.totalDistanceMeters,
    required this.stations,
    this.aroundMe = false,
  });

  final GeoPoint origin;
  final PlaceSuggestion destination;
  final List<GeoPoint> polyline;
  final Duration totalEtaAtMaxSpeed;
  final double totalDistanceMeters;
  final List<FuelStation> stations;
  final bool aroundMe;
}
