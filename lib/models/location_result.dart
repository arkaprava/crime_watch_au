/// A suburb, postcode, or place returned by location search.
class LocationResult {
  const LocationResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  factory LocationResult.fromNominatimJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    final suburb = _firstNonEmpty([
      address['suburb'],
      address['town'],
      address['city'],
      address['village'],
      address['hamlet'],
      address['municipality'],
    ]);
    final postcode = address['postcode'] as String?;
    final state = _abbreviateState(
      address['state'] as String? ?? address['state_code'] as String?,
    );

    final title = suburb ?? _shortDisplayName(json['display_name'] as String?);
    final subtitleParts = [
      ?postcode,
      ?state,
    ];

    return LocationResult(
      title: title,
      subtitle: subtitleParts.isEmpty
          ? (json['display_name'] as String? ?? '')
          : subtitleParts.join(' · '),
      latitude: double.parse(json['lat'] as String),
      longitude: double.parse(json['lon'] as String),
    );
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  static String _shortDisplayName(String? displayName) {
    if (displayName == null || displayName.isEmpty) return 'Unknown';
    return displayName.split(',').first.trim();
  }

  static String? _abbreviateState(String? state) {
    if (state == null) return null;
    const abbreviations = {
      'New South Wales': 'NSW',
      'Victoria': 'VIC',
      'Queensland': 'QLD',
      'South Australia': 'SA',
      'Western Australia': 'WA',
      'Tasmania': 'TAS',
      'Northern Territory': 'NT',
      'Australian Capital Territory': 'ACT',
    };
    return abbreviations[state] ?? state;
  }
}
