import '../models/crime_incident.dart';
import '../models/location_result.dart';
import 'location_search_service.dart';
import 'suburb_index.dart';

/// Resolves map coordinates for incidents that lack a precise point
/// (e.g. suburb aggregates with [GeocodeStatus.unresolved]).
class SuburbGeocodeService {
  SuburbGeocodeService({
    LocationSearchService? search,
    SuburbIndex? suburbIndex,
    this.allowNetworkGeocode = false,
  })  : _search = search ?? LocationSearchService(),
        _suburbIndex = suburbIndex ?? SuburbIndex.instance;

  final LocationSearchService _search;
  final SuburbIndex _suburbIndex;
  final Map<String, ({double lat, double lng})> _cache = {};

  /// When false (default for bulk fetches), only the local suburb index is
  /// used. Network geocoding is reserved for explicit user search actions.
  final bool allowNetworkGeocode;

  /// Fills in missing coordinates using suburb boundary centroid or cached suburb data.
  Future<List<CrimeIncident>> resolveCoordinates(
    List<CrimeIncident> incidents,
  ) async {
    if (incidents.isEmpty) return const [];

    final suburbCoords = <String, ({double lat, double lng})>{};
    final pendingNetwork = <String, CrimeIncident>{};

    for (final incident in incidents) {
      if (incident.isMappable) continue;

      final centroid = incident.suburbCentroid;
      if (centroid != null) {
        final key = _cacheKey(incident);
        suburbCoords[key] = (lat: centroid.latitude, lng: centroid.longitude);
        continue;
      }

      final suburb = incident.suburb;
      if (suburb == null || suburb.isEmpty) continue;

      final key = _cacheKey(incident);
      final cached = _cache[key] ?? suburbCoords[key];
      if (cached != null) {
        suburbCoords[key] = cached;
        continue;
      }

      final suburbEntry = _suburbIndex.findExact(suburb, incident.state);
      if (suburbEntry?.hasCoordinates == true) {
        suburbCoords[key] = (
          lat: suburbEntry!.latitude!,
          lng: suburbEntry.longitude!,
        );
        continue;
      }

      if (allowNetworkGeocode) {
        pendingNetwork.putIfAbsent(key, () => incident);
      }
    }

    if (allowNetworkGeocode && pendingNetwork.isNotEmpty) {
      await Future.wait(
        pendingNetwork.entries.map((entry) async {
          final incident = entry.value;
          try {
            final pending = LocationResult(
              title: incident.suburb!,
              subtitle: incident.state ?? '',
              latitude: 0,
              longitude: 0,
              state: incident.state,
              isSuburbLike: true,
              needsGeocode: true,
            );
            final resolved = await _search.resolveSelection(pending);
            suburbCoords[entry.key] = (
              lat: resolved.latitude,
              lng: resolved.longitude,
            );
          } catch (_) {
            // Leave unresolved; map/list can still show the record.
          }
        }),
      );
    }

    for (final entry in suburbCoords.entries) {
      _cache[entry.key] = entry.value;
    }

    return incidents
        .map((incident) => _applyResolvedCoordinates(incident, suburbCoords))
        .toList(growable: false);
  }

  CrimeIncident _applyResolvedCoordinates(
    CrimeIncident incident,
    Map<String, ({double lat, double lng})> suburbCoords,
  ) {
    if (incident.isMappable) return incident;

    final centroid = incident.suburbCentroid;
    if (centroid != null) {
      return incident.withCoordinates(
        centroid.latitude,
        centroid.longitude,
        resolvedBy: CoordinateSource.suburbCentroid,
      );
    }

    final coords = suburbCoords[_cacheKey(incident)];
    if (coords == null) return incident;

    return incident.withCoordinates(
      coords.lat,
      coords.lng,
      resolvedBy: CoordinateSource.geocodedSuburb,
    );
  }

  String _cacheKey(CrimeIncident incident) =>
      '${incident.suburb?.toLowerCase() ?? ''}|${incident.state ?? ''}';
}
