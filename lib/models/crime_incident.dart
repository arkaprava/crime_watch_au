import 'package:flutter/material.dart';

/// Known crime categories with display metadata.
enum CrimeType {
  theft('Theft', Colors.orange),
  assault('Assault', Colors.red),
  burglary('Burglary', Colors.deepPurple),
  vehicleCrime('Vehicle Crime', Colors.blue),
  drugs('Drugs', Colors.teal),
  vandalism('Vandalism', Colors.brown),
  other('Other', Colors.blueGrey);

  const CrimeType(this.label, this.color);

  final String label;
  final Color color;

  static CrimeType fromApi(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    for (final type in CrimeType.values) {
      if (type.name.toLowerCase() == normalized ||
          type.label.toLowerCase().replaceAll(' ', '') == normalized) {
        return type;
      }
    }
    return CrimeType.other;
  }

  /// Value sent to the GraphQL service.
  String get apiValue => name;
}

/// A single crime incident returned by the GraphQL service.
class CrimeIncident {
  const CrimeIncident({
    required this.id,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.occurredAt,
    this.description,
    this.suburb,
    this.state,
    this.severity = 1,
  });

  final String id;
  final CrimeType type;
  final String? description;
  final double latitude;
  final double longitude;
  final String? suburb;
  final String? state;
  final DateTime occurredAt;

  /// 1 (low) to 3 (high).
  final int severity;

  factory CrimeIncident.fromJson(Map<String, dynamic> json) {
    return CrimeIncident(
      id: json['id'] as String,
      type: CrimeType.fromApi(json['type'] as String? ?? 'other'),
      description: json['description'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      suburb: json['suburb'] as String?,
      state: json['state'] as String?,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      severity: (json['severity'] as num?)?.toInt() ?? 1,
    );
  }

  String get locationLabel {
    if (suburb != null && state != null) return '$suburb, $state';
    return suburb ?? state ?? 'Unknown location';
  }

  String get severityLabel => switch (severity) {
        >= 3 => 'High',
        2 => 'Medium',
        _ => 'Low',
      };
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

  bool contains(double lat, double lng) {
    return lat >= southWestLat &&
        lat <= northEastLat &&
        lng >= southWestLng &&
        lng <= northEastLng;
  }

  Map<String, dynamic> toJson() => {
        'swLat': southWestLat,
        'swLng': southWestLng,
        'neLat': northEastLat,
        'neLng': northEastLng,
      };
}

/// Active filter selection applied to incident queries.
class IncidentFilters {
  const IncidentFilters({
    this.types = const {},
    this.from,
    this.to,
  });

  /// Empty set means "all types".
  final Set<CrimeType> types;
  final DateTime? from;
  final DateTime? to;

  bool get isActive => types.isNotEmpty || from != null || to != null;

  bool matches(CrimeIncident incident) {
    if (types.isNotEmpty && !types.contains(incident.type)) return false;
    if (from != null && incident.occurredAt.isBefore(from!)) return false;
    if (to != null && incident.occurredAt.isAfter(to!)) return false;
    return true;
  }

  IncidentFilters copyWith({
    Set<CrimeType>? types,
    DateTime? Function()? from,
    DateTime? Function()? to,
  }) {
    return IncidentFilters(
      types: types ?? this.types,
      from: from != null ? from() : this.from,
      to: to != null ? to() : this.to,
    );
  }
}
