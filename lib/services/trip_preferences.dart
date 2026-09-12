import 'package:shared_preferences/shared_preferences.dart';

import '../models/geo.dart';

abstract class TripPreferencesStore {
  Future<TripPreferences> load();
  Future<void> save(TripPreferences prefs);
}

class MemoryTripPreferencesStore implements TripPreferencesStore {
  MemoryTripPreferencesStore([this.value = const TripPreferences()]);

  TripPreferences value;

  @override
  Future<TripPreferences> load() async => value;

  @override
  Future<void> save(TripPreferences prefs) async {
    value = prefs;
  }
}

class SharedTripPreferencesStore implements TripPreferencesStore {
  SharedTripPreferencesStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const _fuelKey = 'trip_fuel_kind';
  static const _consumptionKey = 'trip_liters_per_100km';

  final SharedPreferences? _prefsOverride;

  @override
  Future<TripPreferences> load() async {
    final prefs = _prefsOverride ?? await SharedPreferences.getInstance();
    final fuelName = prefs.getString(_fuelKey);
    var fuel = FuelKind.petrol95;
    for (final kind in FuelKind.values) {
      if (kind.name == fuelName) fuel = kind;
    }
    final liters = prefs.getDouble(_consumptionKey) ?? 7.0;
    return TripPreferences(
      fuel: fuel,
      litersPer100km: liters.clamp(1, 40),
    );
  }

  @override
  Future<void> save(TripPreferences value) async {
    final prefs = _prefsOverride ?? await SharedPreferences.getInstance();
    await prefs.setString(_fuelKey, value.fuel.name);
    await prefs.setDouble(_consumptionKey, value.litersPer100km);
  }
}
