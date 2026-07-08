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
  })  : _search = search ?? LocationSearchService(),
        _suburbIndex = suburbIndex ?? SuburbIndex.instance;

  final LocationSearchService _search;
  final SuburbIndex _suburbIndex;
  final Map<String, ({double lat, double lng})> _cache = {};

  /// Fills in missing coordinates using suburb boundary centroid or cached suburb data.
  Future<List<CrimeIncident>> resolveCoordinates(
    List<CrimeIncident> incidents,
  ) async {
    final resolved = <CrimeIncident>[];
    for (final incident in incidents) {
      resolved.add(await _resolveOne(incident));
    }
    return resolved;
  }

  Future<CrimeIncident> _resolveOne(CrimeIncident incident) async {
    if (incident.isMappable) return incident;

    final centroid = incident.suburbCentroid;
    if (centroid != null) {
      return incident.withCoordinates(
        centroid.latitude,
        centroid.longitude,
        resolvedBy: CoordinateSource.suburbCentroid,
      );
    }

    final suburb = incident.suburb;
    if (suburb == null || suburb.isEmpty) return incident;

    final cacheKey = '${suburb.toLowerCase()}|${incident.state ?? ''}';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return incident.withCoordinates(
        cached.lat,
        cached.lng,
        resolvedBy: CoordinateSource.geocodedSuburb,
      );
    }

    final suburbEntry = _suburbIndex.findExact(suburb, incident.state);
    if (suburbEntry?.hasCoordinates == true) {
      _cache[cacheKey] = (
        lat: suburbEntry!.latitude!,
        lng: suburbEntry.longitude!,
      );
      return incident.withCoordinates(
        suburbEntry.latitude!,
        suburbEntry.longitude!,
        resolvedBy: CoordinateSource.geocodedSuburb,
      );
    }

    try {
      final pending = LocationResult(
        title: suburb,
        subtitle: incident.state ?? '',
        latitude: 0,
        longitude: 0,
        state: incident.state,
        isSuburbLike: true,
        needsGeocode: true,
      );
      final resolved = await _search.resolveSelection(pending);
      _cache[cacheKey] = (lat: resolved.latitude, lng: resolved.longitude);
      return incident.withCoordinates(
        resolved.latitude,
        resolved.longitude,
        resolvedBy: CoordinateSource.geocodedSuburb,
      );
    } catch (_) {
      return incident;
    }
  }
}
