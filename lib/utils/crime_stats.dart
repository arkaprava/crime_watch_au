import '../models/crime_incident.dart';
import '../services/crime_query_cache.dart';

/// Builds stable keys for persisted area statistics.
abstract final class CrimeAreaKeys {
  static String suburb(String city, String? state) {
    final stateKey = state?.toUpperCase() ?? '';
    return 'suburb|${city.toLowerCase()}|$stateKey';
  }

  static String viewport(GeoBounds bounds, {String? state}) {
    return 'viewport|${CrimeQueryCache.nearKey(
      latitude: bounds.centerLatitude,
      longitude: bounds.centerLongitude,
      radiusKm: bounds.radiusKm,
      state: state,
    ).replaceFirst('near|', '')}';
  }
}

/// Aggregates incidents into total and per-type counts.
Map<CrimeType, int> aggregateTypeCounts(Iterable<CrimeIncident> incidents) {
  final counts = <CrimeType, int>{};
  for (final incident in incidents) {
    final weight = incident.offenceCount ?? 1;
    counts[incident.type] = (counts[incident.type] ?? 0) + weight;
  }
  return counts;
}

int aggregateTotalCount(Iterable<CrimeIncident> incidents) {
  var total = 0;
  for (final incident in incidents) {
    total += incident.offenceCount ?? 1;
  }
  return total;
}
