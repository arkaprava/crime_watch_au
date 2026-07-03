import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location_result.dart';

/// Geocodes Australian suburbs and postcodes via OpenStreetMap Nominatim.
///
/// No API key is required. Respect the [usage policy](https://operations.osmfoundation.org/policies/nominatim/)
/// by keeping request volume low (the UI debounces input).
class LocationSearchService {
  LocationSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<List<LocationResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'q': '$trimmed, Australia',
        'format': 'json',
        'addressdetails': '1',
        'countrycodes': 'au',
        'limit': '8',
      },
    );

    final response = await _client.get(
      uri,
      headers: const {'User-Agent': 'CrimeWatchAU/1.0 (crime-watch-au-app)'},
    );

    if (response.statusCode != 200) {
      throw LocationSearchException('Search failed (${response.statusCode})');
    }

    final results = (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(LocationResult.fromNominatimJson)
        .toList();

    return _dedupe(results);
  }

  List<LocationResult> _dedupe(List<LocationResult> results) {
    final seen = <String>{};
    return [
      for (final result in results)
        if (seen.add('${result.title}|${result.subtitle}')) result,
    ];
  }
}

class LocationSearchException implements Exception {
  LocationSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}
