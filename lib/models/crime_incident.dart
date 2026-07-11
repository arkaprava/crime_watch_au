import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/reporting_period.dart';

/// How map coordinates were determined for a record.
enum CoordinateSource {
  /// Exact point from the service.
  location,

  /// Suburb boundary centroid from the service.
  suburbCentroid,

  /// Client-side geocode of suburb name.
  geocodedSuburb,
}

/// Record granularity from the Crime Service.
enum RecordGranularity {
  incident('Incident'),
  suburbAggregate('Suburb aggregate'),
  districtAggregate('District aggregate'),
  stateAggregate('State aggregate');

  const RecordGranularity(this.label);
  final String label;

  static RecordGranularity? fromApi(String? value) {
    if (value == null) return null;
    return switch (value.toUpperCase()) {
      'INCIDENT' => RecordGranularity.incident,
      'SUBURB_AGGREGATE' => RecordGranularity.suburbAggregate,
      'DISTRICT_AGGREGATE' => RecordGranularity.districtAggregate,
      'STATE_AGGREGATE' => RecordGranularity.stateAggregate,
      _ => null,
    };
  }
}

/// Geocoding quality from the Crime Service.
enum GeocodeStatus {
  resolved('Resolved'),
  unresolved('Unresolved'),
  approximate('Approximate');

  const GeocodeStatus(this.label);
  final String label;

  static GeocodeStatus? fromApi(String? value) {
    if (value == null) return null;
    return switch (value.toUpperCase()) {
      'RESOLVED' => GeocodeStatus.resolved,
      'UNRESOLVED' => GeocodeStatus.unresolved,
      'APPROXIMATE' => GeocodeStatus.approximate,
      _ => null,
    };
  }
}

/// Crime categories from the Crime Service GraphQL schema.
enum CrimeType {
  theft('Theft', Colors.orange),
  burglary('Burglary', Colors.deepPurple),
  robbery('Robbery', Colors.red),
  assault('Assault', Colors.redAccent),
  homicide('Homicide', Colors.black87),
  kidnapping('Kidnapping', Colors.purple),
  vandalism('Vandalism', Colors.brown),
  fraud('Fraud', Colors.indigo),
  cybercrime('Cybercrime', Colors.cyan),
  drugOffense('Drug Offense', Colors.teal),
  arson('Arson', Colors.deepOrange),
  other('Other', Colors.blueGrey);

  const CrimeType(this.label, this.color);

  final String label;
  final Color color;

  static CrimeType fromApi(String value) {
    final normalized = value.toUpperCase().replaceAll(RegExp(r'[\s-]'), '_');
    return switch (normalized) {
      'THEFT' => CrimeType.theft,
      'BURGLARY' => CrimeType.burglary,
      'ROBBERY' => CrimeType.robbery,
      'ASSAULT' => CrimeType.assault,
      'HOMICIDE' => CrimeType.homicide,
      'KIDNAPPING' => CrimeType.kidnapping,
      'VANDALISM' => CrimeType.vandalism,
      'FRAUD' => CrimeType.fraud,
      'CYBERCRIME' => CrimeType.cybercrime,
      'DRUG_OFFENSE' => CrimeType.drugOffense,
      'ARSON' => CrimeType.arson,
      _ => CrimeType.other,
    };
  }

  String get apiValue => switch (this) {
        CrimeType.theft => 'THEFT',
        CrimeType.burglary => 'BURGLARY',
        CrimeType.robbery => 'ROBBERY',
        CrimeType.assault => 'ASSAULT',
        CrimeType.homicide => 'HOMICIDE',
        CrimeType.kidnapping => 'KIDNAPPING',
        CrimeType.vandalism => 'VANDALISM',
        CrimeType.fraud => 'FRAUD',
        CrimeType.cybercrime => 'CYBERCRIME',
        CrimeType.drugOffense => 'DRUG_OFFENSE',
        CrimeType.arson => 'ARSON',
        CrimeType.other => 'OTHER',
      };
}

/// Severity levels from the Crime Service GraphQL schema.
enum CrimeSeverity {
  low('Low', 1),
  medium('Medium', 2),
  high('High', 3),
  critical('Critical', 4);

  const CrimeSeverity(this.label, this.rank);

  final String label;
  final int rank;

  static CrimeSeverity fromApi(String value) {
    return switch (value.toUpperCase()) {
      'LOW' => CrimeSeverity.low,
      'MEDIUM' => CrimeSeverity.medium,
      'HIGH' => CrimeSeverity.high,
      'CRITICAL' => CrimeSeverity.critical,
      _ => CrimeSeverity.low,
    };
  }
}

/// A point with latitude and longitude.
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// A crime record returned by the Crime Service (incident or aggregate).
class CrimeIncident {
  const CrimeIncident({
    required this.id,
    required this.title,
    required this.type,
    required this.occurredAt,
    this.description,
    this.suburb,
    this.state,
    this.latitude,
    this.longitude,
    this.severity = CrimeSeverity.low,
    this.status,
    this.source,
    this.granularity,
    this.geocodeStatus,
    this.offenceCount,
    this.reportingPeriod,
    this.suburbCentroid,
    this.coordinateSource,
  });

  final String id;
  final String title;
  final CrimeType type;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? suburb;
  final String? state;
  final DateTime occurredAt;
  final CrimeSeverity severity;
  final String? status;
  final String? source;
  final RecordGranularity? granularity;
  final GeocodeStatus? geocodeStatus;
  final int? offenceCount;
  final String? reportingPeriod;
  final GeoPoint? suburbCentroid;
  final CoordinateSource? coordinateSource;

  /// Parses a [CrimeIncident] node from the Crime Service GraphQL response.
  factory CrimeIncident.fromGraphQl(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    final coordinates = location?['coordinates'] as Map<String, dynamic>?;
    final boundary = json['suburbBoundary'] as Map<String, dynamic>?;
    final centroid = boundary?['centroid'] as Map<String, dynamic>?;

    double? lat = (coordinates?['latitude'] as num?)?.toDouble();
    double? lng = (coordinates?['longitude'] as num?)?.toDouble();
    CoordinateSource? source;
    GeoPoint? suburbCentroid;

    if (lat != null && lng != null) {
      source = CoordinateSource.location;
    } else if (centroid != null) {
      lat = (centroid['latitude'] as num?)?.toDouble();
      lng = (centroid['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        suburbCentroid = GeoPoint(latitude: lat, longitude: lng);
        source = CoordinateSource.suburbCentroid;
      }
    }

    return CrimeIncident(
      id: json['id'] as String,
      title: json['title'] as String,
      type: CrimeType.fromApi(json['crimeType'] as String? ?? 'OTHER'),
      description: json['description'] as String?,
      latitude: lat,
      longitude: lng,
      suburb: location?['city'] as String? ?? boundary?['name'] as String?,
      state: location?['state'] as String? ?? boundary?['state'] as String?,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      severity: CrimeSeverity.fromApi(json['severity'] as String? ?? 'LOW'),
      status: json['status'] as String?,
      source: json['source'] as String?,
      granularity: RecordGranularity.fromApi(json['granularity'] as String?),
      geocodeStatus: GeocodeStatus.fromApi(json['geocodeStatus'] as String?),
      offenceCount: (json['offenceCount'] as num?)?.toInt(),
      reportingPeriod: json['reportingPeriod'] as String?,
      suburbCentroid: suburbCentroid,
      coordinateSource: source,
    );
  }

  bool get isMappable => latitude != null && longitude != null;

  bool get isAggregate =>
      granularity != null && granularity != RecordGranularity.incident;

  bool get hasExactCoordinates =>
      coordinateSource == CoordinateSource.location;

  /// Whether the detail UI should show a lat/lng coordinate row.
  bool get showsCoordinateDetails =>
      isMappable && granularity != RecordGranularity.suburbAggregate;

  /// Human-readable duration for aggregate reporting periods.
  String? get reportingPeriodLabel => formatReportingPeriod(reportingPeriod);

  String get locationLabel {
    if (suburb != null && state != null) return '$suburb, $state';
    return suburb ?? state ?? 'Unknown location';
  }

  String get severityLabel => severity.label;

  int get severityRank => severity.rank;

  String? get granularityLabel => granularity?.label;

  String get coordinateLabel => switch (coordinateSource) {
        CoordinateSource.location => 'Exact location',
        CoordinateSource.suburbCentroid => 'Suburb centre',
        CoordinateSource.geocodedSuburb => 'Approximate (suburb)',
        null => 'Location unavailable',
      };

  CrimeIncident withCoordinates(
    double lat,
    double lng, {
    required CoordinateSource resolvedBy,
  }) {
    return CrimeIncident(
      id: id,
      title: title,
      type: type,
      occurredAt: occurredAt,
      description: description,
      suburb: suburb,
      state: state,
      latitude: lat,
      longitude: lng,
      severity: severity,
      status: status,
      source: source,
      granularity: granularity,
      geocodeStatus: geocodeStatus,
      offenceCount: offenceCount,
      reportingPeriod: reportingPeriod,
      suburbCentroid: suburbCentroid,
      coordinateSource: resolvedBy,
    );
  }
}

/// A geographic bounding box used to query incidents for the visible map area.
class GeoBounds {
  const GeoBounds({
    required this.southWestLat,
    required this.southWestLng,
    required this.northEastLat,
    required this.northEastLng,
  });

  final double southWestLat;
  final double southWestLng;
  final double northEastLat;
  final double northEastLng;

  double get centerLatitude => (southWestLat + northEastLat) / 2;

  double get centerLongitude => (southWestLng + northEastLng) / 2;

  double get radiusKm {
    final distance = _haversineKm(
      centerLatitude,
      centerLongitude,
      northEastLat,
      northEastLng,
    );
    return distance.clamp(0.5, 200.0);
  }

  double get latSpanDegrees => (northEastLat - southWestLat).abs();

  double get lngSpanDegrees => (northEastLng - southWestLng).abs();

  /// The backend `crimesNearLocation` query is expensive; skip it when the map
  /// is zoomed out beyond roughly city level (e.g. continental Australia view).
  bool get supportsNearLocationQuery {
    const maxSpanDegrees = 1.2;
    return latSpanDegrees <= maxSpanDegrees && lngSpanDegrees <= maxSpanDegrees;
  }

  bool contains(double lat, double lng) {
    return lat >= southWestLat &&
        lat <= northEastLat &&
        lng >= southWestLng &&
        lng <= northEastLng;
  }
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180;

/// Optional suburb/city filter from location search.
class ActiveArea {
  const ActiveArea({this.city, this.state});

  final String? city;
  final String? state;

  bool get isActive => city != null && city!.isNotEmpty;
}

/// Active filter selection applied to incident queries.
class IncidentFilters {
  const IncidentFilters({
    this.types = const {},
    this.from,
    this.to,
    this.state,
  });

  final Set<CrimeType> types;
  final DateTime? from;
  final DateTime? to;
  final String? state;

  bool get isActive =>
      types.isNotEmpty || from != null || to != null || state != null;

  bool matches(CrimeIncident incident) {
    if (types.isNotEmpty && !types.contains(incident.type)) return false;
    if (from != null && incident.occurredAt.isBefore(from!)) return false;
    if (to != null && incident.occurredAt.isAfter(to!)) return false;
    if (state != null &&
        incident.state != null &&
        incident.state!.toUpperCase() != state!.toUpperCase()) {
      return false;
    }
    return true;
  }

  IncidentFilters copyWith({
    Set<CrimeType>? types,
    DateTime? Function()? from,
    DateTime? Function()? to,
    String? Function()? state,
  }) {
    return IncidentFilters(
      types: types ?? this.types,
      from: from != null ? from() : this.from,
      to: to != null ? to() : this.to,
      state: state != null ? state() : this.state,
    );
  }
}
