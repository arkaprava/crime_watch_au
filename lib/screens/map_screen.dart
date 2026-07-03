import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:platform_maps_flutter/platform_maps_flutter.dart';

import '../config/app_config.dart';
import '../models/crime_incident.dart';
import '../models/location_result.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_bar.dart';
import '../widgets/incident_detail_sheet.dart';
import '../widgets/location_search_bar.dart';
import '../widgets/marker_icons.dart';
import '../widgets/surface_card.dart';
import 'incident_list_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  PlatformMapController? _controller;
  Timer? _cameraDebounce;
  bool _centeredOnUser = false;

  @override
  void dispose() {
    _cameraDebounce?.cancel();
    super.dispose();
  }

  Future<void> _refreshViewport() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final region = await controller.getVisibleRegion();
      ref.read(viewportProvider.notifier).update(
            GeoBounds(
              southWestLat: region.southwest.latitude,
              southWestLng: region.southwest.longitude,
              northEastLat: region.northeast.latitude,
              northEastLng: region.northeast.longitude,
            ),
          );
    } catch (_) {
      // Visible region can fail while the map is initialising.
    }
  }

  void _onMapCreated(PlatformMapController controller) {
    _controller = controller;
    Future.delayed(const Duration(milliseconds: 400), _refreshViewport);
  }

  void _onCameraIdle() {
    _cameraDebounce?.cancel();
    _cameraDebounce =
        Timer(const Duration(milliseconds: 500), _refreshViewport);
  }

  Future<void> _animateTo(double lat, double lng, {double zoom = 14}) async {
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), zoom),
    );
  }

  Future<void> _goToUserLocation() async {
    final position = ref.read(userLocationProvider).value;
    if (position != null) {
      await _animateTo(position.latitude, position.longitude, zoom: 13);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location unavailable. Enable location permissions.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onLocationSelected(LocationResult location) {
    _animateTo(location.latitude, location.longitude);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing ${location.title}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openList() async {
    final selected = await Navigator.of(context).push<CrimeIncident>(
      MaterialPageRoute(builder: (_) => const IncidentListScreen()),
    );
    if (selected != null && _controller != null && mounted) {
      await _animateTo(selected.latitude, selected.longitude, zoom: 15);
      if (mounted) {
        await IncidentDetailSheet.show(context, selected);
      }
    }
  }

  Set<Marker> _buildMarkers(List<CrimeIncident> incidents) {
    return incidents
        .map(
          (incident) => Marker(
            markerId: MarkerId(incident.id),
            position: LatLng(incident.latitude, incident.longitude),
            icon: MarkerIconFactory.iconFor(incident.type),
            onTap: () => IncidentDetailSheet.show(context, incident),
          ),
        )
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final incidents = ref.watch(incidentsProvider);
    final theme = Theme.of(context);

    ref.listen<AsyncValue<Position?>>(userLocationProvider, (_, next) {
      final position = next.value;
      if (position != null && !_centeredOnUser && _controller != null) {
        _centeredOnUser = true;
        _animateTo(position.latitude, position.longitude, zoom: 13);
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_moon, color: AppTheme.navy, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(AppConfig.appName),
          ],
        ),
      ),
      body: Stack(
        children: [
          PlatformMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                AppConfig.fallbackLatitude,
                AppConfig.fallbackLongitude,
              ),
              zoom: 13,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _buildMarkers(incidents.value ?? const []),
            onMapCreated: _onMapCreated,
            onCameraIdle: _onCameraIdle,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LocationSearchBar(onLocationSelected: _onLocationSelected),
                  const SizedBox(height: 10),
                  const FilterBar(),
                  const SizedBox(height: 10),
                  _IncidentCountBadge(incidents: incidents),
                ],
              ),
            ),
          ),
          if (incidents.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppTheme.amber,
                backgroundColor: Colors.transparent,
              ),
            ),
          if (incidents.hasError)
            Positioned(
              left: 16,
              right: 16,
              bottom: 96,
              child: SurfaceCard(
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Could not load incidents. Check your connection.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(incidentsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'locate',
                  onPressed: _goToUserLocation,
                  tooltip: 'My location',
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'list',
                  onPressed: _openList,
                  tooltip: 'Incident list',
                  child: const Icon(Icons.format_list_bulleted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentCountBadge extends StatelessWidget {
  const _IncidentCountBadge({required this.incidents});

  final AsyncValue<List<CrimeIncident>> incidents;

  @override
  Widget build(BuildContext context) {
    final count = incidents.value?.length;
    if (count == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 16, color: AppTheme.navy),
            const SizedBox(width: 6),
            Text(
              count == 0
                  ? 'No incidents in this area'
                  : '$count incident${count == 1 ? '' : 's'} nearby',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
