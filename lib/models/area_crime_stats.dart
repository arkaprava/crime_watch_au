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

  /// Latitude/longitude parsed from a `viewport|lat|lng|...` area key, if any.
  (double, double)? get viewportCoordinates {
    final parts = areaKey.split('|');
    if (parts.first != 'viewport' || parts.length < 3) return null;
    final lat = double.tryParse(parts[1]);
    final lng = double.tryParse(parts[2]);
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }

  /// True when selecting this area can re-open it on the map.
  bool get isActionable => isSuburb
      ? (suburb != null && suburb!.isNotEmpty)
      : viewportCoordinates != null;

  /// Human-readable label for the area.
  String get displayName {
    final name = suburb;
    if (name != null && name.isNotEmpty) {
      final code = state;
      return code != null && code.isNotEmpty ? '$name, $code' : name;
    }
    final coords = viewportCoordinates;
    if (coords != null) {
      return 'Map area · '
          '${coords.$1.toStringAsFixed(2)}, ${coords.$2.toStringAsFixed(2)}';
    }
    return 'Saved area';
  }
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
