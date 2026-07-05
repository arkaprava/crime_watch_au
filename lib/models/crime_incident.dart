import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  /// GraphQL enum value for [crimeIncidents] filters.
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

/// A single crime incident returned by the Crime Service.
class CrimeIncident {
  const CrimeIncident({
    required this.id,
    required this.title,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.occurredAt,
    this.description,
    this.suburb,
    this.state,
    this.severity = CrimeSeverity.low,
    this.status,
  });

  final String id;
  final String title;
  final CrimeType type;
  final String? description;
  final double latitude;
  final double longitude;
  final String? suburb;
  final String? state;
  final DateTime occurredAt;
  final CrimeSeverity severity;
  final String? status;

  /// Parses a [CrimeIncident] node from the Crime Service GraphQL response.
  factory CrimeIncident.fromGraphQl(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    final coordinates = location?['coordinates'] as Map<String, dynamic>?;

    return CrimeIncident(
      id: json['id'] as String,
      title: json['title'] as String,
      type: CrimeType.fromApi(json['crimeType'] as String? ?? 'OTHER'),
      description: json['description'] as String?,
      latitude: (coordinates?['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (coordinates?['longitude'] as num?)?.toDouble() ?? 0,
      suburb: location?['city'] as String?,
      state: location?['state'] as String?,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      severity: CrimeSeverity.fromApi(json['severity'] as String? ?? 'LOW'),
      status: json['status'] as String?,
    );
  }

  bool get hasCoordinates => latitude != 0 || longitude != 0;

  String get locationLabel {
    if (suburb != null && state != null) return '$suburb, $state';
    return suburb ?? state ?? 'Unknown location';
  }

  String get severityLabel => severity.label;

  int get severityRank => severity.rank;
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

  /// Approximate search radius in km from the map viewport centre to a corner.
  double get radiusKm {
    final distance = _haversineKm(
      centerLatitude,
      centerLongitude,
      northEastLat,
      northEastLng,
    );
    return distance.clamp(0.5, 200.0);
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

/// Active filter selection applied to incident queries.
class IncidentFilters {
  const IncidentFilters({
    this.types = const {},
    this.from,
    this.to,
    this.state,
  });

  /// Empty set means "all types".
  final Set<CrimeType> types;
  final DateTime? from;
  final DateTime? to;

  /// Optional state filter passed to [crimesNearLocation].
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
