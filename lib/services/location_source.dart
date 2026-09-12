import 'package:geolocator/geolocator.dart';

import '../models/geo.dart';
import 'geo_math.dart';

class LocationFix {
  const LocationFix({
    required this.point,
    required this.isFallback,
    this.note,
  });

  final GeoPoint point;
  final bool isFallback;
  final String? note;
}

abstract class LocationSource {
  Future<LocationFix> currentOrDefault();
}

class DeviceLocationSource implements LocationSource {
  const DeviceLocationSource();

  @override
  Future<LocationFix> currentOrDefault() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return const LocationFix(
          point: vilniusDefault,
          isFallback: true,
          note: 'Vietos tarnybos išjungtos — naudojama Vilniaus centras.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return const LocationFix(
          point: vilniusDefault,
          isFallback: true,
          note:
              'Nėra vietos leidimo — maršrutas nuo Vilniaus centro. Įjunkite vietą tikslesniam keliui.',
        );
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return LocationFix(
          point: GeoPoint(lat: last.latitude, lon: last.longitude),
          isFallback: false,
        );
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LocationFix(
        point: GeoPoint(lat: current.latitude, lon: current.longitude),
        isFallback: false,
      );
    } catch (_) {
      return const LocationFix(
        point: vilniusDefault,
        isFallback: true,
        note: 'Nepavyko nustatyti vietos — naudojama Vilniaus centras.',
      );
    }
  }
}
