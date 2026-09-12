import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/geo.dart';
import '../services/geo_math.dart';
import '../state/trip_controller.dart';
import 'theme.dart';

class TripPage extends StatefulWidget {
  const TripPage({super.key, this.showMap = true});

  final bool showMap;

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  late final TripController _trip;
  late final TextEditingController _destination;
  late final MapController _map;
  late final FocusNode _focus;

  String? _cameraKey;
  bool _syncingQuery = false;

  @override
  void initState() {
    super.initState();
    _trip = context.read<TripController>();
    _destination = TextEditingController(text: _trip.query);
    _map = MapController();
    _focus = FocusNode();
    _trip.addListener(_syncField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _trip.ensureOrigin();
    });
  }

  void _syncField() {
    final trip = _trip;
    if (_destination.text != trip.query) {
      _syncingQuery = true;
      _destination.value = TextEditingValue(
        text: trip.query,
        selection: TextSelection.collapsed(offset: trip.query.length),
      );
      _syncingQuery = false;
    }
    _applyCameraIfNeeded();
  }

  void _applyCameraIfNeeded() {
    final plan = _trip.plan;
    if (!widget.showMap || !mounted) return;
    if (plan == null) {
      _cameraKey = null;
      return;
    }
    final key = plan.aroundMe
        ? 'around:${plan.origin.lat.toStringAsFixed(4)},${plan.origin.lon.toStringAsFixed(4)}'
        : 'route:${plan.destination.label}:${plan.origin.lat.toStringAsFixed(4)}:${plan.polyline.length}';
    if (key == _cameraKey) return;
    _cameraKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _cameraKey != key) return;
      _moveCamera(plan);
    });
  }

  void _moveCamera(TripPlan plan) {
    try {
      final size = _map.camera.nonRotatedSize;
      if (!size.width.isFinite ||
          !size.height.isFinite ||
          size.width < 8 ||
          size.height < 8) {
        _cameraKey = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyCameraIfNeeded();
        });
        return;
      }
      if (plan.aroundMe) {
        _map.move(LatLng(plan.origin.lat, plan.origin.lon), 13);
        return;
      }
      _fitPlan(plan);
    } catch (_) {
      _cameraKey = null;
    }
  }

  void _fitPlan(TripPlan plan) {
    final pts = [
      ...plan.polyline,
      plan.origin,
      plan.destination.point,
      ...plan.stations.map((s) => s.point),
    ];
    if (pts.isEmpty) return;
    var minLat = pts.first.lat;
    var maxLat = pts.first.lat;
    var minLon = pts.first.lon;
    var maxLon = pts.first.lon;
    for (final p in pts) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lon < minLon) minLon = p.lon;
      if (p.lon > maxLon) maxLon = p.lon;
    }
    try {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(minLat, minLon),
            LatLng(maxLat, maxLon),
          ),
          padding: const EdgeInsets.fromLTRB(40, 160, 40, 200),
          maxZoom: 16,
          minZoom: 8,
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _trip.removeListener(_syncField);
    _destination.dispose();
    _map.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripController>();
    return Stack(
      children: [
        Positioned.fill(child: widget.showMap ? _MapView(map: _map) : _MapStub(trip: trip)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _SearchCard(
              destination: _destination,
              focus: _focus,
              onQueryChanged: (value) {
                if (_syncingQuery) return;
                _trip.onQueryChanged(value);
              },
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _StationPanel(onSelect: _onStationTap),
        ),
      ],
    );
  }

  void _onStationTap(FuelStation station) {
    final trip = context.read<TripController>();
    trip.selectStation(station);
    if (!widget.showMap) return;
    try {
      _map.move(
        LatLng(station.point.lat, station.point.lon),
        _map.camera.zoom,
      );
    } catch (_) {}
  }
}

class _MapStub extends StatelessWidget {
  const _MapStub({required this.trip});
  final TripController trip;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE7EEEA),
      child: Center(
        child: Text(
          trip.plan == null ? 'Žemėlapis' : 'Maršrutas iki ${trip.plan!.destination.label}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _MapView extends StatefulWidget {
  const _MapView({required this.map});
  final MapController map;

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  late final MapOptions _options;

  @override
  void initState() {
    super.initState();
    final trip = context.read<TripController>();
    _options = MapOptions(
      initialCenter: LatLng(trip.origin.lat, trip.origin.lon),
      initialZoom: 13,
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
      onTap: (_, _) => trip.selectStation(null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripController>();
    final plan = trip.plan;
    final origin = LatLng(trip.origin.lat, trip.origin.lon);
    final selected = trip.selectedStation;

    return FlutterMap(
      mapController: widget.map,
      options: _options,
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'lt.almantask.budget_app',
        ),
        if (plan != null && !plan.aroundMe && plan.polyline.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  for (final p in plan.polyline) LatLng(p.lat, p.lon),
                ],
                strokeWidth: 5,
                color: AppTheme.seed,
              ),
            ],
          ),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap'),
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: origin,
              width: 40,
              height: 40,
              child: const _Pin(
                icon: Icons.my_location,
                color: Color(0xFF1D4ED8),
              ),
            ),
            if (plan != null && !plan.aroundMe)
              Marker(
                point: LatLng(
                  plan.destination.point.lat,
                  plan.destination.point.lon,
                ),
                width: 40,
                height: 40,
                child: const _Pin(
                  icon: Icons.flag,
                  color: Color(0xFFB91C1C),
                ),
              ),
            if (plan != null)
              for (final station in trip.visibleStations)
                Marker(
                  point: LatLng(station.point.lat, station.point.lon),
                  width: 36,
                  height: 36,
                  child: GestureDetector(
                    onTap: () => trip.selectStation(station),
                    child: _Pin(
                      icon: Icons.local_gas_station,
                      color: selected?.id == station.id
                          ? const Color(0xFFB45309)
                          : const Color(0xFF0F6B5C),
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.destination,
    required this.focus,
    required this.onQueryChanged,
  });

  final TextEditingController destination;
  final FocusNode focus;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripController>();
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.my_location, size: 18, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.locating ? 'Nustatoma dabartinė vieta…' : 'Iš: ${trip.originLabel}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Nustatymai',
                  onPressed: () => showTripSettingsSheet(context, trip),
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            if (trip.originNote != null) ...[
              const SizedBox(height: 4),
              Text(
                trip.originNote!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: destination,
              focusNode: focus,
              textInputAction: TextInputAction.search,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Kur važiuojate?',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: trip.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Išvalyti',
                        onPressed: trip.clearDestination,
                        icon: const Icon(Icons.close),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                avatar: Icon(
                  Icons.near_me,
                  size: 18,
                  color: trip.aroundMeSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.primary,
                ),
                label: const Text('Aplink mane'),
                selected: trip.aroundMeSelected,
                onSelected: (selected) {
                  focus.unfocus();
                  if (selected) {
                    trip.selectAroundMe();
                  } else {
                    trip.clearDestination();
                  }
                },
              ),
            ),
            if (trip.searching)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (trip.suggestions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: trip.suggestions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = trip.suggestions[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(place.label),
                      subtitle: place.subtitle == null
                          ? null
                          : Text(
                              place.subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () {
                        focus.unfocus();
                        trip.selectDestination(place);
                      },
                    );
                  },
                ),
              ),
            if (trip.planning)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (trip.plan != null && !trip.planning) ...[
              const SizedBox(height: 10),
              Text(
                trip.plan!.aroundMe
                    ? 'Aplink jus · ${trip.visibleStations.length} degalinės · ${trip.preferences.fuel.label}'
                    : 'Iki ${trip.plan!.destination.label} · '
                        '${formatDistanceKm(trip.plan!.totalDistanceMeters)} · '
                        'maks. greičiu ${formatMaxSpeedEta(trip.plan!.totalEtaAtMaxSpeed)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            if (trip.error != null && trip.suggestions.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                trip.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StationPanel extends StatelessWidget {
  const _StationPanel({required this.onSelect});

  final ValueChanged<FuelStation> onSelect;

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripController>();
    if (trip.plan == null && !trip.planning) {
      return const SizedBox.shrink();
    }

    final stations = trip.visibleStations;
    final expanded = trip.listExpanded;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: trip.toggleStationList,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Icon(Icons.local_gas_station, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip.planning
                              ? 'Ieškoma degalinių maršrute…'
                              : stations.isEmpty
                                  ? 'Degalinių maršrute nėra'
                                  : 'Degalinės · ${stations.length}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Tooltip(
                        message: expanded ? 'Sutraukti' : 'Išskleisti',
                        child: Icon(
                          expanded ? Icons.expand_more : Icons.expand_less,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded && !trip.planning && stations.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    itemCount: stations.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final station = stations[index];
                      final selected = trip.selectedStation?.id == station.id;
                      return ListTile(
                        selected: selected,
                        leading: CircleAvatar(
                          backgroundColor: selected
                              ? const Color(0xFFB45309)
                              : scheme.primary.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.local_gas_station,
                            color: selected ? Colors.white : scheme.primary,
                          ),
                        ),
                        title: Text(station.name),
                        subtitle: Text(
                          station.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatMaxSpeedEta(station.etaAtMaxSpeed),
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              'maks. greičiu',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        onTap: () => onSelect(station),
                      );
                    },
                  ),
                ),
              if (expanded && !trip.planning && stations.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    trip.plan?.aroundMe == true
                        ? 'Netoliese degalinių nerasta.'
                        : 'Palei šį kelią degalinių nerasta.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showTripSettingsSheet(BuildContext context, TripController trip) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return ChangeNotifierProvider.value(
        value: trip,
        child: const _TripSettingsSheet(),
      );
    },
  );
}

class _TripSettingsSheet extends StatefulWidget {
  const _TripSettingsSheet();

  @override
  State<_TripSettingsSheet> createState() => _TripSettingsSheetState();
}

class _TripSettingsSheetState extends State<_TripSettingsSheet> {
  late final TextEditingController _consumption;

  @override
  void initState() {
    super.initState();
    _consumption = TextEditingController(
      text: context.read<TripController>().preferences.litersPer100km.toString(),
    );
  }

  @override
  void dispose() {
    _consumption.dispose();
    super.dispose();
  }

  Future<void> _saveConsumption(TripController trip) async {
    final parsed = double.tryParse(_consumption.text.replaceAll(',', '.'));
    if (parsed == null) return;
    await trip.updatePreferences(
      trip.preferences.copyWith(litersPer100km: parsed.clamp(1, 40)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripController>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nustatymai', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _consumption,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Mašinos kuro sąnaudos',
              suffixText: 'l/100 km',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _saveConsumption(trip),
            onEditingComplete: () => _saveConsumption(trip),
          ),
          const SizedBox(height: 16),
          Text('Naudojamas kuras', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final kind in FuelKind.values)
                ChoiceChip(
                  label: Text(kind.label),
                  selected: trip.preferences.fuel == kind,
                  onSelected: (_) {
                    trip.updatePreferences(trip.preferences.copyWith(fuel: kind));
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
