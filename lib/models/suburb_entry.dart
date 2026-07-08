/// A cached Australian suburb used for local autocomplete.
class SuburbEntry {
  const SuburbEntry({
    required this.name,
    required this.state,
    this.postcode,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String state;
  final String? postcode;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory SuburbEntry.fromJson(Map<String, dynamic> json) {
    return SuburbEntry(
      name: json['n'] as String,
      state: json['s'] as String,
      postcode: json['p'] as String?,
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lng'] as num?)?.toDouble(),
    );
  }
}
