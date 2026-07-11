import '../models/crime_incident.dart';

/// Persisted crime counts for a suburb or map viewport.
class AreaCrimeStats {
  const AreaCrimeStats({
    required this.areaKey,
    required this.totalCount,
    required this.typeCounts,
    required this.updatedAt,
    this.suburb,
    this.state,
  });

  final String areaKey;
  final String? suburb;
  final String? state;
  final int totalCount;
  final Map<CrimeType, int> typeCounts;
  final DateTime updatedAt;

  bool get isSuburb => areaKey.startsWith('suburb|');
  bool get isViewport => areaKey.startsWith('viewport|');
}

/// A single crime-type tally for an area.
class AreaCrimeTypeCount {
  const AreaCrimeTypeCount({
    required this.areaKey,
    required this.type,
    required this.count,
  });

  final String areaKey;
  final CrimeType type;
  final int count;
}
