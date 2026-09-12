import 'dart:math' as math;

import '../models/geo.dart';

const vilniusDefault = GeoPoint(lat: 54.687157, lon: 25.279652);

/// Lithuanian motorway legal maximum — used as a fallback when routing
/// duration is unavailable. Per-road speed limits come from OSRM.
const maxLegalSpeedKmh = 130.0;

double haversineMeters(GeoPoint a, GeoPoint b) {
  const radius = 6371000.0;
  final dLat = _rad(b.lat - a.lat);
  final dLon = _rad(b.lon - a.lon);
  final sinLat = math.sin(dLat / 2);
  final sinLon = math.sin(dLon / 2);
  final h = sinLat * sinLat +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * sinLon * sinLon;
  return 2 * radius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

double distanceToPolylineMeters(GeoPoint point, List<GeoPoint> line) {
  if (line.isEmpty) return double.infinity;
  if (line.length == 1) return haversineMeters(point, line.first);
  var best = double.infinity;
  for (var i = 0; i < line.length - 1; i++) {
    final d = _distanceToSegmentMeters(point, line[i], line[i + 1]);
    if (d < best) best = d;
  }
  return best;
}

/// Distance along the polyline from the start to the closest point on it.
double distanceAlongPolylineMeters(GeoPoint point, List<GeoPoint> line) {
  if (line.length < 2) return 0;
  var bestDist = double.infinity;
  var along = 0.0;
  var walked = 0.0;
  for (var i = 0; i < line.length - 1; i++) {
    final a = line[i];
    final b = line[i + 1];
    final seg = haversineMeters(a, b);
    final t = _projectionT(point, a, b);
    final proj = GeoPoint(
      lat: a.lat + (b.lat - a.lat) * t,
      lon: a.lon + (b.lon - a.lon) * t,
    );
    final d = haversineMeters(point, proj);
    if (d < bestDist) {
      bestDist = d;
      along = walked + seg * t;
    }
    walked += seg;
  }
  return along;
}

List<GeoPoint> samplePolyline(List<GeoPoint> points, {int maxPoints = 48}) {
  if (points.length <= maxPoints) return List<GeoPoint>.from(points);
  if (maxPoints < 2) return [points.first];
  final step = (points.length - 1) / (maxPoints - 1);
  return [
    for (var i = 0; i < maxPoints; i++) points[(i * step).round()],
  ];
}

Duration etaAtMaxSpeed({
  required double distanceMeters,
  Duration? routedDuration,
}) {
  if (routedDuration != null && routedDuration > Duration.zero) {
    return routedDuration;
  }
  final hours = distanceMeters / 1000.0 / maxLegalSpeedKmh;
  final seconds = (hours * 3600).round().clamp(1, 24 * 3600);
  return Duration(seconds: seconds);
}

String formatMaxSpeedEta(Duration duration) {
  final totalSeconds = duration.inSeconds;
  if (totalSeconds < 60) return 'mažiau nei 1 min';
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '$hours val.';
  return '$hours val. $minutes min';
}

String formatDistanceKm(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
}

String stationAddressFromTags(
  Map<String, String> tags, {
  String? reverseGeocoded,
}) {
  final full = tags['addr:full']?.trim();
  if (full != null && full.isNotEmpty) return full;

  final streetParts = <String>[
    if ((tags['addr:street'] ?? '').trim().isNotEmpty) tags['addr:street']!.trim(),
    if ((tags['addr:housenumber'] ?? '').trim().isNotEmpty)
      tags['addr:housenumber']!.trim(),
  ];
  final city = (tags['addr:city'] ??
          tags['addr:town'] ??
          tags['addr:village'] ??
          tags['addr:suburb'] ??
          '')
      .trim();
  final parts = <String>[
    if (streetParts.isNotEmpty) streetParts.join(' '),
    if (city.isNotEmpty) city,
  ];
  if (parts.isNotEmpty) return parts.join(', ');

  final reverse = reverseGeocoded?.trim();
  if (reverse != null && reverse.isNotEmpty) return reverse;
  return 'Adresas nenurodytas';
}

String stationNameFromTags(Map<String, String> tags) {
  for (final key in ['brand', 'name', 'operator', 'brand:lt']) {
    final value = tags[key]?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return 'Degalinė';
}

double _rad(double degrees) => degrees * math.pi / 180;

double _projectionT(GeoPoint p, GeoPoint a, GeoPoint b) {
  final dx = b.lon - a.lon;
  final dy = b.lat - a.lat;
  final denom = dx * dx + dy * dy;
  if (denom == 0) return 0;
  final t = ((p.lon - a.lon) * dx + (p.lat - a.lat) * dy) / denom;
  return t.clamp(0.0, 1.0);
}

double _distanceToSegmentMeters(GeoPoint p, GeoPoint a, GeoPoint b) {
  final t = _projectionT(p, a, b);
  final proj = GeoPoint(
    lat: a.lat + (b.lat - a.lat) * t,
    lon: a.lon + (b.lon - a.lon) * t,
  );
  return haversineMeters(p, proj);
}
