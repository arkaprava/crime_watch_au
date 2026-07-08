import '../config/app_config.dart';
import '../models/crime_incident.dart';

/// In-memory TTL cache for parsed GraphQL crime query results.
class CrimeQueryCache {
  CrimeQueryCache({Duration? ttl})
      : ttl = ttl ?? AppConfig.graphqlCacheTtl;

  final Duration ttl;
  final Map<String, _CacheEntry> _entries = {};

  List<CrimeIncident>? get(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    return List<CrimeIncident>.from(entry.incidents);
  }

  void put(String key, List<CrimeIncident> incidents) {
    _entries[key] = _CacheEntry(
      incidents: List<CrimeIncident>.from(incidents),
      expiresAt: DateTime.now().add(ttl),
    );
  }

  void invalidate(String key) => _entries.remove(key);

  void invalidateSuburb(String city, String? state) {
    final prefix = suburbPrefix(city, state);
    _entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  void invalidateNear({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? state,
  }) {
    invalidate(nearKey(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      state: state,
    ));
  }

  void clear() => _entries.clear();

  void invalidateViewport({
    required GeoBounds bounds,
    String? state,
    ActiveArea? area,
  }) {
    invalidateNear(
      latitude: bounds.centerLatitude,
      longitude: bounds.centerLongitude,
      radiusKm: bounds.radiusKm,
      state: state,
    );
    final city = area?.city;
    if (city != null && city.isNotEmpty) {
      invalidateSuburb(city, area?.state);
    }
  }

  static String nearKey({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? state,
  }) {
    final lat = latitude.toStringAsFixed(2);
    final lng = longitude.toStringAsFixed(2);
    final radius = radiusKm.toStringAsFixed(1);
    final stateKey = state?.toUpperCase() ?? '';
    return 'near|$lat|$lng|$radius|$stateKey';
  }

  static String suburbPageKey({
    required String city,
    String? state,
    required int limit,
    required int offset,
  }) {
    final stateKey = state?.toUpperCase() ?? '';
    return 'suburb|${city.toLowerCase()}|$stateKey|$limit|$offset';
  }

  static String suburbPrefix(String city, String? state) {
    final stateKey = state?.toUpperCase() ?? '';
    return 'suburb|${city.toLowerCase()}|$stateKey|';
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.incidents,
    required this.expiresAt,
  });

  final List<CrimeIncident> incidents;
  final DateTime expiresAt;
}
