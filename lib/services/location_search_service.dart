import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location_result.dart';
import '../models/suburb_entry.dart';
import 'suburb_index.dart';

/// Local suburb autocomplete backed by a bundled cache, with optional
/// Nominatim geocoding when a selected suburb lacks coordinates.
class LocationSearchService {
  LocationSearchService({
    http.Client? client,
    SuburbIndex? suburbIndex,
  })  : _client = client ?? http.Client(),
        _suburbIndex = suburbIndex ?? SuburbIndex.instance;

  final http.Client _client;
  final SuburbIndex _suburbIndex;

  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';

  /// Instant prefix search against the bundled suburb cache.
  Future<List<LocationResult>> search(String query) async {
    return _suburbIndex.searchAsLocationResults(query);
  }

  /// Resolves coordinates for a suburb selected from autocomplete.
  Future<LocationResult> resolveSelection(LocationResult result) async {
    if (!result.needsGeocode) return result;

    final cached = _suburbIndex.findExact(result.title, result.state);
    if (cached?.hasCoordinates == true) {
      return _fromSuburbEntry(cached!);
    }

    return _geocodeSuburb(result.title, result.state);
  }

  Future<LocationResult> _geocodeSuburb(String suburb, String? state) async {
    final query = state != null
        ? '$suburb, $state, Australia'
        : '$suburb, Australia';

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'countrycodes': 'au',
        'limit': '5',
      },
    );

    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': 'CrimeWatchAU/1.0 (crime-watch-au-app)',
        'Accept-Language': 'en-AU,en',
      },
    );

    if (response.statusCode != 200) {
      throw LocationSearchException('Search failed (${response.statusCode})');
    }

    final raw = (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();

    final results = raw
        .map(LocationResult.fromNominatimJson)
        .where((item) => item.title.isNotEmpty)
        .toList();

    if (results.isEmpty) {
      throw LocationSearchException('No coordinates found for $suburb');
    }

    final exact = results.where(
      (item) => item.title.toLowerCase() == suburb.toLowerCase(),
    );
    final match = exact.isNotEmpty ? exact.first : results.first;

    return LocationResult(
      title: suburb,
      subtitle: match.subtitle,
      latitude: match.latitude,
      longitude: match.longitude,
      state: state ?? match.state,
      isSuburbLike: true,
    );
  }

  LocationResult _fromSuburbEntry(SuburbEntry entry) {
    final subtitleParts = [
      ?entry.postcode,
      entry.state,
    ];
    return LocationResult(
      title: entry.name,
      subtitle: subtitleParts.join(' · '),
      latitude: entry.latitude!,
      longitude: entry.longitude!,
      state: entry.state,
      isSuburbLike: true,
    );
  }
}

class LocationSearchException implements Exception {
  LocationSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}
