import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/geo.dart';
import '../services/geo_math.dart';
import '../services/location_source.dart';
import '../services/trip_routing.dart';

class TripController extends ChangeNotifier {
  TripController({
    TripRoutingService? routing,
    LocationSource? location,
  })  : routing = routing ?? TripRoutingService(),
        location = location ?? const DeviceLocationSource();

  final TripRoutingService routing;
  final LocationSource location;

  GeoPoint origin = vilniusDefault;
  String originLabel = 'Dabartinė vieta';
  String? originNote;
  bool originIsFallback = true;

  String query = '';
  List<PlaceSuggestion> suggestions = const [];
  PlaceSuggestion? destination;
  TripPlan? plan;
  FuelStation? selectedStation;

  bool listExpanded = true;
  bool locating = false;
  bool searching = false;
  bool planning = false;
  String? error;

  Timer? _debounce;

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
    notifyListeners();

    final reverse = await routing.reverseGeocode(origin);
    if (reverse != null && reverse.isNotEmpty) {
      originLabel = fix.isFallback ? 'Vilnius (numatytoji)' : reverse;
      notifyListeners();
    }
    if (destination != null && previous != origin) {
      await selectDestination(destination!);
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
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
