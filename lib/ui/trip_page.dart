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
      _destination.value = TextEditingValue(
        text: trip.query,
        selection: TextSelection.collapsed(offset: trip.query.length),
      );
    }
    final plan = trip.plan;
    if (plan != null && widget.showMap && mounted) {
      _fitPlan(plan);
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
      _map.move(LatLng(station.point.lat, station.point.lon), 14);
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

class _MapView extends StatelessWidget {
  const _MapView({required this.map});
  final MapController map;

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripController>();
    final plan = trip.plan;
    final origin = LatLng(trip.origin.lat, trip.origin.lon);
    final selected = trip.selectedStation;

    return FlutterMap(
      mapController: map,
      options: MapOptions(
        initialCenter: origin,
        initialZoom: 12,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, _) => trip.selectStation(null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'lt.almantask.budget_app',
        ),
        if (plan != null)
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
        SimpleAttributionWidget(
          source: const Text('OpenStreetMap'),
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
            if (plan != null)
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
              for (final station in plan.stations)
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
  });

  final TextEditingController destination;
  final FocusNode focus;

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
              onChanged: trip.onQueryChanged,
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
                'Iki ${trip.plan!.destination.label} · '
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

    final stations = trip.plan?.stations ?? const <FuelStation>[];
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
                    'Palei šį kelią degalinių nerasta.',
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
