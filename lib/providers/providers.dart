import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/area_crime_stats.dart';
import '../models/crime_incident.dart';
import '../repositories/crime_repository.dart';
import '../services/crime_data_sync_service.dart';
import '../services/crime_local_database.dart';
import '../services/crime_query_cache.dart';
import '../services/crime_session_cache.dart';
import '../utils/crime_stats.dart';

final crimeLocalDatabaseProvider = Provider<CrimeLocalDatabase>((ref) {
  throw UnimplementedError(
    'crimeLocalDatabaseProvider must be overridden in main()',
  );
});

final crimeSessionCacheProvider = Provider<CrimeSessionCache>((ref) {
  return CrimeSessionCache();
});

final crimeQueryCacheProvider = Provider<CrimeQueryCache>((ref) {
  return CrimeQueryCache();
});

final crimeRepositoryProvider = Provider<CrimeRepository>((ref) {
  return CrimeRepository(
    createGraphQLClient(),
    cache: ref.watch(crimeQueryCacheProvider),
    localDatabase: ref.watch(crimeLocalDatabaseProvider),
    sessionCache: ref.watch(crimeSessionCacheProvider),
  );
});

final crimeDataSyncServiceProvider = Provider<CrimeDataSyncService>((ref) {
  return CrimeDataSyncService(
    repository: ref.watch(crimeRepositoryProvider),
    database: ref.watch(crimeLocalDatabaseProvider),
    sessionCache: ref.watch(crimeSessionCacheProvider),
  );
});

/// Runs once per app session to refresh persisted area statistics.
final launchSyncProvider = FutureProvider<void>((ref) async {
  await ref.watch(crimeDataSyncServiceProvider).refreshOnLaunch();
});

/// Persisted crime counts/types for a suburb or viewport key.
final areaCrimeStatsProvider =
    FutureProvider.family<AreaCrimeStats?, String>((ref, areaKey) async {
  final database = ref.watch(crimeLocalDatabaseProvider);
  return database.getAreaStats(areaKey);
});

/// All locally stored area statistics, newest first.
final storedAreaStatsProvider = FutureProvider<List<AreaCrimeStats>>((ref) async {
  final database = ref.watch(crimeLocalDatabaseProvider);
  return database.listAreas();
});

/// Active crime-type / date-range filters.
class FiltersNotifier extends Notifier<IncidentFilters> {
  @override
  IncidentFilters build() => const IncidentFilters();

  void toggleType(CrimeType type) {
    final types = Set<CrimeType>.from(state.types);
    if (!types.remove(type)) types.add(type);
    state = state.copyWith(types: types);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(from: () => from, to: () => to);
  }

  void clear() => state = const IncidentFilters();
}

final filtersProvider = NotifierProvider<FiltersNotifier, IncidentFilters>(
  FiltersNotifier.new,
);

/// The currently visible map region; updated (debounced) as the camera moves.
class ViewportNotifier extends Notifier<GeoBounds?> {
  @override
  GeoBounds? build() => null;

  void update(GeoBounds bounds) => state = bounds;
}

final viewportProvider = NotifierProvider<ViewportNotifier, GeoBounds?>(
  ViewportNotifier.new,
);

/// Suburb/city selected via location search; triggers [crimeIncidents] fetch.
class ActiveAreaNotifier extends Notifier<ActiveArea?> {
  @override
  ActiveArea? build() => null;

  void setArea(String? city, String? stateCode) {
    if (city == null || city.isEmpty) {
      state = null;
      return;
    }
    state = ActiveArea(city: city, state: stateCode);
  }

  void clear() => state = null;
}

final activeAreaProvider = NotifierProvider<ActiveAreaNotifier, ActiveArea?>(
  ActiveAreaNotifier.new,
);

/// Incidents for the current viewport and filters.
final incidentsProvider = FutureProvider<List<CrimeIncident>>((ref) async {
  final bounds = ref.watch(viewportProvider);
  final filters = ref.watch(filtersProvider);
  final area = ref.watch(activeAreaProvider);
  if (bounds == null) return const [];
  if (!bounds.supportsNearLocationQuery) return const [];
  final repository = ref.watch(crimeRepositoryProvider);
  return repository.fetchIncidents(bounds: bounds, filters: filters, area: area);
});

/// Incidents for the suburb selected via location search.
final suburbIncidentsProvider = FutureProvider<List<CrimeIncident>>((ref) async {
  final area = ref.watch(activeAreaProvider);
  final filters = ref.watch(filtersProvider);
  if (area == null || !area.isActive) return const [];
  final repository = ref.watch(crimeRepositoryProvider);
  return repository.fetchSuburbIncidents(
    city: area.city!,
    state: area.state,
    filters: filters,
  );
});

/// Session-cached incident detail by id.
final incidentDetailProvider =
    Provider.family<CrimeIncident?, String>((ref, id) {
  return ref.watch(crimeSessionCacheProvider).get(id);
});

/// Best-effort user location; null when permission is denied or
/// location services are unavailable.
final userLocationProvider = FutureProvider<Position?>((ref) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
  } catch (_) {
    return null;
  }
});

/// Area key for the current viewport statistics.
String? currentViewportAreaKey(GeoBounds? bounds, IncidentFilters filters) {
  if (bounds == null) return null;
  return CrimeAreaKeys.viewport(bounds, state: filters.state);
}

/// Area key for the active suburb statistics.
String? currentSuburbAreaKey(ActiveArea? area) {
  if (area == null || !area.isActive) return null;
  return CrimeAreaKeys.suburb(area.city!, area.state);
}
