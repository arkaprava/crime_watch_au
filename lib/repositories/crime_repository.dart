import 'package:graphql/client.dart';

import '../config/app_config.dart';
import '../data/demo_incidents.dart';
import '../graphql/incidents_query.dart';
import '../models/crime_incident.dart';
import '../services/crime_query_cache.dart';
import '../services/suburb_geocode_service.dart';

/// Fetches crime incidents from the Crime Service GraphQL API.
class CrimeRepository {
  CrimeRepository(
    this._client, {
    SuburbGeocodeService? geocodeService,
    CrimeQueryCache? cache,
  })  : _geocodeService = geocodeService ?? SuburbGeocodeService(),
        _cache = cache ?? CrimeQueryCache();

  final GraphQLClient _client;
  final SuburbGeocodeService _geocodeService;
  final CrimeQueryCache _cache;

  CrimeQueryCache get cache => _cache;

  Future<List<CrimeIncident>> fetchIncidents({
    required GeoBounds bounds,
    IncidentFilters filters = const IncidentFilters(),
    ActiveArea? area,
    bool refresh = false,
  }) async {
    if (AppConfig.useDemoData) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return buildDemoIncidents()
          .where((i) => i.isMappable && bounds.contains(i.latitude!, i.longitude!))
          .where(filters.matches)
          .toList();
    }

    final merged = <String, CrimeIncident>{};

    final nearIncidents = await _fetchNearIncidents(
      bounds: bounds,
      state: filters.state,
      refresh: refresh,
    );
    _addIncidents(merged, nearIncidents);

    final city = area?.city;
    if (city != null && city.isNotEmpty) {
      final cityIncidents = await _fetchCityIncidents(
        city: city,
        state: area?.state ?? filters.state,
        refresh: refresh,
      );
      _addIncidents(merged, cityIncidents);
    }

    final resolved = await _geocodeService.resolveCoordinates(merged.values.toList());

    return resolved
        .where(filters.matches)
        .where(
          (i) =>
              !i.isMappable ||
              bounds.contains(i.latitude!, i.longitude!) ||
              (city != null &&
                  i.suburb?.toLowerCase() == city.toLowerCase()),
        )
        .toList();
  }

  static const _pageSize = 200;
  static const _maxRecords = 1000;

  /// Fetches all crime records for a suburb, paginating through the API.
  Future<List<CrimeIncident>> fetchSuburbIncidents({
    required String city,
    String? state,
    IncidentFilters filters = const IncidentFilters(),
    int limit = _pageSize,
    int offset = 0,
    bool refresh = false,
  }) async {
    if (AppConfig.useDemoData) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return buildDemoIncidents()
          .where(
            (i) => i.suburb?.toLowerCase() == city.toLowerCase(),
          )
          .where(filters.matches)
          .toList();
    }

    final merged = <String, CrimeIncident>{};
    var currentOffset = offset;
    final pageLimit = limit.clamp(1, _pageSize);
    final resolvedState = state;

    while (merged.length < _maxRecords) {
      final cacheKey = CrimeQueryCache.suburbPageKey(
        city: city,
        state: resolvedState,
        limit: pageLimit,
        offset: currentOffset,
      );

      List<CrimeIncident> pageIncidents;
      if (!refresh) {
        final cached = _cache.get(cacheKey);
        if (cached != null) {
          pageIncidents = cached;
        } else {
          pageIncidents = await _querySuburbPage(
            city: city,
            state: resolvedState,
            filters: filters,
            limit: pageLimit,
            offset: currentOffset,
          );
          _cache.put(cacheKey, pageIncidents);
        }
      } else {
        pageIncidents = await _querySuburbPage(
          city: city,
          state: resolvedState,
          filters: filters,
          limit: pageLimit,
          offset: currentOffset,
        );
        _cache.put(cacheKey, pageIncidents);
      }

      if (pageIncidents.isEmpty) break;

      for (final incident in pageIncidents) {
        merged[incident.id] = incident;
      }
      currentOffset += pageIncidents.length;

      if (pageIncidents.length < pageLimit) break;
    }

    final resolved =
        await _geocodeService.resolveCoordinates(merged.values.toList());
    return resolved.where(filters.matches).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  Future<List<CrimeIncident>> _fetchNearIncidents({
    required GeoBounds bounds,
    String? state,
    required bool refresh,
  }) async {
    final cacheKey = CrimeQueryCache.nearKey(
      latitude: bounds.centerLatitude,
      longitude: bounds.centerLongitude,
      radiusKm: bounds.radiusKm,
      state: state,
    );

    if (!refresh) {
      final cached = _cache.get(cacheKey);
      if (cached != null) return cached;
    }

    final variables = <String, dynamic>{
      'latitude': bounds.centerLatitude,
      'longitude': bounds.centerLongitude,
      'radiusKm': bounds.radiusKm,
    };
    if (state != null) {
      variables['state'] = state;
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(crimesNearLocationDocument),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (result.hasException) throw result.exception!;

    final incidents = _parseIncidents(result.data?['crimesNearLocation']);
    _cache.put(cacheKey, incidents);
    return incidents;
  }

  Future<List<CrimeIncident>> _fetchCityIncidents({
    required String city,
    String? state,
    required bool refresh,
  }) async {
    final cacheKey = CrimeQueryCache.suburbPageKey(
      city: city,
      state: state,
      limit: _pageSize,
      offset: 0,
    );

    if (!refresh) {
      final cached = _cache.get(cacheKey);
      if (cached != null) return cached;
    }

    final incidents = await _querySuburbPage(
      city: city,
      state: state,
      filters: const IncidentFilters(),
      limit: _pageSize,
      offset: 0,
    );
    _cache.put(cacheKey, incidents);
    return incidents;
  }

  Future<List<CrimeIncident>> _querySuburbPage({
    required String city,
    String? state,
    required IncidentFilters filters,
    required int limit,
    required int offset,
  }) async {
    final variables = <String, dynamic>{
      'city': city,
      'limit': limit,
      'offset': offset,
    };
    final resolvedState = state ?? filters.state;
    if (resolvedState != null) {
      variables['state'] = resolvedState;
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(crimeIncidentsDocument),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (result.hasException) throw result.exception!;
    return _parseIncidents(result.data?['crimeIncidents']);
  }

  List<CrimeIncident> _parseIncidents(List<dynamic>? nodes) {
    final incidents = <CrimeIncident>[];
    for (final node in nodes ?? const []) {
      incidents.add(
        CrimeIncident.fromGraphQl((node as Map).cast<String, dynamic>()),
      );
    }
    return incidents;
  }

  void _addIncidents(
    Map<String, CrimeIncident> merged,
    List<CrimeIncident> incidents,
  ) {
    for (final incident in incidents) {
      merged[incident.id] = incident;
    }
  }
}

/// Builds the GraphQL client pointed at the configured endpoint.
GraphQLClient createGraphQLClient() {
  final headers = <String, String>{};
  if (AppConfig.apiKey.isNotEmpty) {
    headers['X-API-Key'] = AppConfig.apiKey;
  }
  final link = HttpLink(
    AppConfig.graphqlEndpoint,
    defaultHeaders: headers,
  );
  return GraphQLClient(link: link, cache: GraphQLCache());
}
