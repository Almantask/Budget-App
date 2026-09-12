import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/geo.dart';
import '../services/geo_math.dart';
import '../services/location_source.dart';
import '../services/trip_preferences.dart';
import '../services/trip_routing.dart';

class TripController extends ChangeNotifier {
  TripController({
    TripRoutingService? routing,
    LocationSource? location,
    TripPreferencesStore? preferencesStore,
  })  : routing = routing ?? TripRoutingService(),
        location = location ?? const DeviceLocationSource(),
        preferencesStore = preferencesStore ?? SharedTripPreferencesStore() {
    unawaited(loadPreferences());
  }

  final TripRoutingService routing;
  final LocationSource location;
  final TripPreferencesStore preferencesStore;

  GeoPoint origin = vilniusDefault;
  String originLabel = 'Dabartinė vieta';
  String? originNote;
  bool originIsFallback = true;

  String query = '';
  List<PlaceSuggestion> suggestions = const [];
  PlaceSuggestion? destination;
  TripPlan? plan;
  FuelStation? selectedStation;
  TripPreferences preferences = const TripPreferences();

  bool listExpanded = true;
  bool locating = false;
  bool searching = false;
  bool planning = false;
  String? error;

  Timer? _debounce;

  bool originReady = false;
  bool _awaitingOriginForAroundMe = false;

  bool get aroundMeSelected =>
      plan?.aroundMe == true ||
      destination?.isAroundMe == true ||
      _awaitingOriginForAroundMe;

  List<FuelStation> get visibleStations {
    final stations = plan?.stations ?? const <FuelStation>[];
    return [
      for (final station in stations)
        if (station.offers(preferences.fuel)) station,
    ];
  }

  Future<void> loadPreferences() async {
    preferences = await preferencesStore.load();
    notifyListeners();
  }

  Future<void> updatePreferences(TripPreferences value) async {
    preferences = value;
    notifyListeners();
    await preferencesStore.save(value);
  }

  Future<void> ensureOrigin() async {
    if (locating) return;
    locating = true;
    error = null;
    notifyListeners();
    final previous = origin;
    final fix = await location.currentOrDefault();
    origin = fix.point;
    originIsFallback = fix.isFallback;
    originNote = fix.note;
    originLabel = fix.isFallback ? 'Vilnius (numatytoji)' : 'Dabartinė vieta';
    locating = false;
    originReady = true;
    notifyListeners();

    if (_awaitingOriginForAroundMe) {
      _awaitingOriginForAroundMe = false;
      await selectAroundMe();
    } else if (destination != null && haversineMeters(previous, origin) > 250) {
      if (destination!.isAroundMe) {
        await selectAroundMe();
      } else {
        await selectDestination(destination!);
      }
    }

    final reverse = await routing.reverseGeocode(origin);
    if (reverse != null && reverse.isNotEmpty) {
      originLabel = fix.isFallback ? 'Vilnius (numatytoji)' : reverse;
      notifyListeners();
    }
  }

  void onQueryChanged(String value) {
    query = value;
    destination = null;
    plan = null;
    selectedStation = null;
    error = null;
    _debounce?.cancel();
    if (value.trim().length < 2) {
      suggestions = const [];
      searching = false;
      notifyListeners();
      return;
    }
    searching = true;
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_search(value));
    });
  }

  Future<void> _search(String value) async {
    try {
      final results = await routing.searchPlaces(value, near: origin);
      if (query != value) return;
      suggestions = results;
      searching = false;
      if (results.isEmpty) {
        error = 'Tokios vietos nerasta.';
      }
      notifyListeners();
    } catch (e) {
      if (query != value) return;
      searching = false;
      suggestions = const [];
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> selectDestination(PlaceSuggestion place) async {
    _debounce?.cancel();
    query = place.label;
    destination = place;
    suggestions = const [];
    selectedStation = null;
    error = null;
    planning = true;
    notifyListeners();
    try {
      plan = await routing.planTrip(origin: origin, destination: place);
      listExpanded = true;
      planning = false;
      notifyListeners();
    } catch (e) {
      plan = null;
      planning = false;
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> selectAroundMe() async {
    if (planning) return;
    if (!originReady || locating) {
      _awaitingOriginForAroundMe = true;
      query = PlaceSuggestion.aroundMeLabel;
      destination = PlaceSuggestion.aroundMe(origin);
      suggestions = const [];
      notifyListeners();
      return;
    }
    if (plan?.aroundMe == true && haversineMeters(plan!.origin, origin) <= 250) {
      query = PlaceSuggestion.aroundMeLabel;
      destination = PlaceSuggestion.aroundMe(origin);
      suggestions = const [];
      notifyListeners();
      return;
    }
    _debounce?.cancel();
    query = PlaceSuggestion.aroundMeLabel;
    destination = PlaceSuggestion.aroundMe(origin);
    suggestions = const [];
    selectedStation = null;
    error = null;
    planning = true;
    notifyListeners();
    try {
      plan = await routing.planAroundMe(origin);
      listExpanded = true;
      planning = false;
      notifyListeners();
    } catch (e) {
      plan = null;
      planning = false;
      error = e.toString();
      notifyListeners();
    }
  }

  void selectStation(FuelStation? station) {
    selectedStation = station;
    notifyListeners();
  }

  void toggleStationList() {
    listExpanded = !listExpanded;
    notifyListeners();
  }

  void setStationListExpanded(bool expanded) {
    listExpanded = expanded;
    notifyListeners();
  }

  void clearDestination() {
    _debounce?.cancel();
    query = '';
    suggestions = const [];
    destination = null;
    plan = null;
    selectedStation = null;
    error = null;
    planning = false;
    searching = false;
    _awaitingOriginForAroundMe = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
