import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geo.dart';
import 'geo_math.dart';

class TripRoutingException implements Exception {
  const TripRoutingException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TripRoutingService {
  TripRoutingService({
    http.Client? httpClient,
    this.nominatimBase = 'https://nominatim.openstreetmap.org',
    this.photonBase = 'https://photon.komoot.io',
    this.osrmBase = 'https://router.project-osrm.org',
    this.overpassUrl = 'https://overpass-api.de/api/interpreter',
  }) : _http = httpClient ?? http.Client();

  static const userAgent = 'SeimosBiudzetas/1.0 (Almantask/Budget-App)';
  static const corridorMeters = 800.0;

  final http.Client _http;
  final String nominatimBase;
  final String photonBase;
  final String osrmBase;
  final String overpassUrl;

  Map<String, String> get _jsonHeaders => {
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Accept-Language': 'lt',
      };

  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    GeoPoint? near,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final params = <String, String>{
      'q': trimmed,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '6',
      'accept-language': 'lt',
    };
    if (near != null) {
      params['viewbox'] =
          '${near.lon - 1},${near.lat + 1},${near.lon + 1},${near.lat - 1}';
      params['bounded'] = '0';
    }

    final uri = Uri.parse('$nominatimBase/search').replace(queryParameters: params);
    final response = await _http.get(uri, headers: _jsonHeaders);
    if (response.statusCode != 200) {
      throw const TripRoutingException('Nepavyko rasti vietos. Bandykite dar kartą.');
    }

    final raw = jsonDecode(response.body);
    if (raw is! List) return const [];
    final seen = <String>{};
    final results = <PlaceSuggestion>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      final display = (item['display_name'] as String?)?.trim();
      if (lat == null || lon == null || display == null || display.isEmpty) {
        continue;
      }
      final key = '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
      if (!seen.add(key)) continue;
      results.add(
        PlaceSuggestion(
          label: _shortLabel(item, display),
          subtitle: display,
          point: GeoPoint(lat: lat, lon: lon),
        ),
      );
    }
    return results;
  }

  Future<String?> reverseGeocode(GeoPoint point) async {
    try {
      final photon = await _photonReverse(point);
      if (photon != null) return photon;
    } catch (_) {}
    try {
      return await _nominatimReverse(point);
    } catch (_) {
      return null;
    }
  }

  Future<TripPlan> planTrip({
    required GeoPoint origin,
    required PlaceSuggestion destination,
  }) async {
    final route = await _drivingRoute(origin, destination.point);
    final polyline = route.polyline;
    if (polyline.length < 2) {
      throw const TripRoutingException('Nepavyko sudaryti maršruto iki tikslo.');
    }

    final stations = await _stationsAlong(polyline);
    final withEta = await _attachEtas(origin, stations, polyline);

    return TripPlan(
      origin: origin,
      destination: destination,
      polyline: polyline,
      totalEtaAtMaxSpeed: route.duration,
      totalDistanceMeters: route.distanceMeters,
      stations: withEta,
    );
  }

  Future<_OsrmRoute> _drivingRoute(GeoPoint from, GeoPoint to) async {
    final path =
        '$osrmBase/route/v1/driving/${from.lon},${from.lat};${to.lon},${to.lat}';
    final uri = Uri.parse(path).replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );
    final response = await _http.get(uri, headers: _jsonHeaders);
    if (response.statusCode != 200) {
      throw const TripRoutingException('Nepavyko gauti maršruto.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['code'] != 'Ok') {
      throw const TripRoutingException('Maršrutas iki šio tikslo nerastas.');
    }
    final routes = body['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw const TripRoutingException('Maršrutas iki šio tikslo nerastas.');
    }
    final first = routes.first as Map<String, dynamic>;
    final geometry = first['geometry'] as Map<String, dynamic>?;
    final coords = geometry?['coordinates'] as List<dynamic>? ?? [];
    final polyline = <GeoPoint>[];
    for (final pair in coords) {
      if (pair is! List || pair.length < 2) continue;
      final lon = (pair[0] as num).toDouble();
      final lat = (pair[1] as num).toDouble();
      polyline.add(GeoPoint(lat: lat, lon: lon));
    }
    final seconds = ((first['duration'] as num?) ?? 0).toDouble();
    final meters = ((first['distance'] as num?) ?? 0).toDouble();
    return _OsrmRoute(
      polyline: polyline,
      duration: Duration(seconds: seconds.round()),
      distanceMeters: meters,
    );
  }

  Future<List<_RawStation>> _stationsAlong(List<GeoPoint> polyline) async {
    final sampled = samplePolyline(polyline, maxPoints: 40);
    final around = sampled.map((p) => '${p.lat},${p.lon}').join(',');
    final query = '''
[out:json][timeout:25];
(
  node["amenity"="fuel"](around:${corridorMeters.round()},$around);
  way["amenity"="fuel"](around:${corridorMeters.round()},$around);
);
out center tags;
''';
    final response = await _http.post(
      Uri.parse(overpassUrl),
      headers: {
        ..._jsonHeaders,
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      },
      body: 'data=${Uri.encodeComponent(query)}',
    );
    if (response.statusCode != 200) {
      throw const TripRoutingException('Nepavyko gauti degalinių palei maršrutą.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = body['elements'] as List<dynamic>? ?? [];
    final stations = <_RawStation>[];
    final seen = <String>{};
    for (final raw in elements) {
      if (raw is! Map) continue;
      final point = _elementPoint(raw);
      if (point == null) continue;
      if (distanceToPolylineMeters(point, polyline) > corridorMeters) continue;
      final id = '${raw['type']}-${raw['id']}';
      if (!seen.add(id)) continue;
      final tags = _stringTags(raw['tags']);
      stations.add(
        _RawStation(
          id: id,
          name: stationNameFromTags(tags),
          address: stationAddressFromTags(tags),
          tags: tags,
          point: point,
          alongMeters: distanceAlongPolylineMeters(point, polyline),
        ),
      );
    }
    stations.sort((a, b) => a.alongMeters.compareTo(b.alongMeters));
    if (stations.length > 30) {
      return stations.sublist(0, 30);
    }
    return stations;
  }

  Future<List<FuelStation>> _attachEtas(
    GeoPoint origin,
    List<_RawStation> stations,
    List<GeoPoint> polyline,
  ) async {
    if (stations.isEmpty) return const [];

    final durations = await _tableDurations(origin, stations.map((s) => s.point));
    final resolved = <FuelStation>[];
    for (var i = 0; i < stations.length; i++) {
      final raw = stations[i];
      var address = raw.address;
      if (address == 'Adresas nenurodytas') {
        final reverse = await reverseGeocode(raw.point);
        address = stationAddressFromTags(raw.tags, reverseGeocoded: reverse);
      }
      final routed = i < durations.length ? durations[i] : null;
      final distance = routed == null
          ? haversineMeters(origin, raw.point)
          : raw.alongMeters;
      resolved.add(
        FuelStation(
          id: raw.id,
          name: raw.name,
          address: address,
          point: raw.point,
          etaAtMaxSpeed: etaAtMaxSpeed(
            distanceMeters: distance > 0 ? distance : haversineMeters(origin, raw.point),
            routedDuration: routed,
          ),
          distanceMeters: distance > 0 ? distance : haversineMeters(origin, raw.point),
        ),
      );
    }
    return resolved;
  }

  Future<List<Duration?>> _tableDurations(
    GeoPoint origin,
    Iterable<GeoPoint> destinations,
  ) async {
    final points = [origin, ...destinations];
    if (points.length < 2) return const [];
    final coords = points.map((p) => '${p.lon},${p.lat}').join(';');
    final uri = Uri.parse('$osrmBase/table/v1/driving/$coords').replace(
      queryParameters: {
        'sources': '0',
        'annotations': 'duration,distance',
      },
    );
    try {
      final response = await _http.get(uri, headers: _jsonHeaders);
      if (response.statusCode != 200) {
        return List<Duration?>.filled(points.length - 1, null);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') {
        return List<Duration?>.filled(points.length - 1, null);
      }
      final matrix = body['durations'] as List<dynamic>?;
      final row = matrix != null && matrix.isNotEmpty ? matrix.first as List<dynamic> : [];
      return [
        for (var i = 1; i < points.length; i++)
          i < row.length && row[i] != null
              ? Duration(seconds: ((row[i] as num).round()))
              : null,
      ];
    } catch (_) {
      return List<Duration?>.filled(points.length - 1, null);
    }
  }

  Future<String?> _photonReverse(GeoPoint point) async {
    final uri = Uri.parse('$photonBase/reverse').replace(
      queryParameters: {
        'lon': '${point.lon}',
        'lat': '${point.lat}',
        'lang': 'lt',
      },
    );
    final response = await _http.get(uri, headers: _jsonHeaders);
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = body['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return null;
    final props = (features.first as Map<String, dynamic>)['properties'];
    if (props is! Map) return null;
    final streetParts = <String>[
      if ('${props['street'] ?? ''}'.trim().isNotEmpty) '${props['street']}'.trim(),
      if ('${props['housenumber'] ?? ''}'.trim().isNotEmpty)
        '${props['housenumber']}'.trim(),
    ];
    final city = '${props['city'] ?? props['locality'] ?? props['district'] ?? ''}'.trim();
    final parts = <String>[
      if (streetParts.isNotEmpty) streetParts.join(' '),
      if (city.isNotEmpty) city,
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    final name = '${props['name'] ?? ''}'.trim();
    return name.isEmpty ? null : name;
  }

  Future<String?> _nominatimReverse(GeoPoint point) async {
    final uri = Uri.parse('$nominatimBase/reverse').replace(
      queryParameters: {
        'lat': '${point.lat}',
        'lon': '${point.lon}',
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'lt',
      },
    );
    final response = await _http.get(uri, headers: _jsonHeaders);
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final address = body['address'];
    if (address is Map) {
      final streetParts = <String>[
        if ('${address['road'] ?? ''}'.trim().isNotEmpty) '${address['road']}'.trim(),
        if ('${address['house_number'] ?? ''}'.trim().isNotEmpty)
          '${address['house_number']}'.trim(),
      ];
      final city = '${address['city'] ?? address['town'] ?? address['village'] ?? ''}'
          .trim();
      final parts = <String>[
        if (streetParts.isNotEmpty) streetParts.join(' '),
        if (city.isNotEmpty) city,
      ];
      if (parts.isNotEmpty) return parts.join(', ');
    }
    final display = (body['display_name'] as String?)?.trim();
    return display == null || display.isEmpty ? null : display;
  }

  GeoPoint? _elementPoint(Map raw) {
    final lat = (raw['lat'] as num?)?.toDouble();
    final lon = (raw['lon'] as num?)?.toDouble();
    if (lat != null && lon != null) return GeoPoint(lat: lat, lon: lon);
    final center = raw['center'];
    if (center is Map) {
      final cLat = (center['lat'] as num?)?.toDouble();
      final cLon = (center['lon'] as num?)?.toDouble();
      if (cLat != null && cLon != null) return GeoPoint(lat: cLat, lon: cLon);
    }
    return null;
  }

  Map<String, String> _stringTags(Object? raw) {
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        if (entry.key != null && entry.value != null) '${entry.key}': '${entry.value}',
    };
  }

  String _shortLabel(Map item, String display) {
    final named = (item['name'] as String?)?.trim();
    if (named != null && named.isNotEmpty) return named;
    final address = item['address'];
    if (address is Map) {
      for (final key in ['road', 'suburb', 'city', 'town', 'village']) {
        final value = '${address[key] ?? ''}'.trim();
        if (value.isNotEmpty) return value;
      }
    }
    return display.split(',').first.trim();
  }
}

class _OsrmRoute {
  const _OsrmRoute({
    required this.polyline,
    required this.duration,
    required this.distanceMeters,
  });

  final List<GeoPoint> polyline;
  final Duration duration;
  final double distanceMeters;
}

class _RawStation {
  const _RawStation({
    required this.id,
    required this.name,
    required this.address,
    required this.tags,
    required this.point,
    required this.alongMeters,
  });

  final String id;
  final String name;
  final String address;
  final Map<String, String> tags;
  final GeoPoint point;
  final double alongMeters;
}
