import '../models/crime_incident.dart';

/// Session-scoped in-memory cache of full crime incident details.
///
/// Cleared when the app process restarts. Use for detail views within a session.
class CrimeSessionCache {
  final Map<String, CrimeIncident> _incidents = {};

  void put(CrimeIncident incident) => _incidents[incident.id] = incident;

  void putAll(Iterable<CrimeIncident> incidents) {
    for (final incident in incidents) {
      put(incident);
    }
  }

  CrimeIncident? get(String id) => _incidents[id];

  /// Returns the cached copy when available, otherwise the provided incident.
  CrimeIncident resolve(CrimeIncident incident) =>
      _incidents[incident.id] ?? incident;

  bool contains(String id) => _incidents.containsKey(id);

  int get length => _incidents.length;

  void clear() => _incidents.clear();
}
