import 'dart:async';

import 'package:graphql/client.dart';

import '../config/app_config.dart';
import '../data/demo_incidents.dart';
import '../graphql/incidents_query.dart';
import '../models/crime_incident.dart';
import '../services/crime_local_database.dart';
import '../services/crime_session_cache.dart';
import '../services/crime_query_cache.dart';
import '../services/suburb_geocode_service.dart';
import '../utils/crime_stats.dart';

/// Fetches crime incidents from the Crime Service GraphQL API.
class CrimeRepository {
  CrimeRepository(
    this._client, {
    SuburbGeocodeService? geocodeService,
    CrimeQueryCache? cache,
    CrimeLocalDatabase? localDatabase,
    CrimeSessionCache? sessionCache,
  })  : _geocodeService = geocodeService ?? SuburbGeocodeService(),
        _cache = cache ?? CrimeQueryCache(),
        _localDatabase = localDatabase,
        _sessionCache = sessionCache;

  final GraphQLClient _client;
  final SuburbGeocodeService _geocodeService;
  final CrimeQueryCache _cache;
  final CrimeLocalDatabase? _localDatabase;
  final CrimeSessionCache? _sessionCache;

  CrimeQueryCache get cache => _cache;
  CrimeLocalDatabase? get localDatabase => _localDatabase;
  CrimeSessionCache? get sessionCache => _sessionCache;

  Future<List<CrimeIncident>> fetchIncidents({
    required GeoBounds bounds,
    IncidentFilters filters = const IncidentFilters(),
    ActiveArea? area,
    bool refresh = false,
  }) async {
    if (AppConfig.useDemoData) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final incidents = buildDemoIncidents()
          .where((i) => i.isMappable && bounds.contains(i.latitude!, i.longitude!))
          .where(filters.matches)
          .toList();
      _persistAndCache(
        incidents,
        areaKey: CrimeAreaKeys.viewport(bounds, state: filters.state),
      );
      return incidents;
    }

    final merged = <String, CrimeIncident>{};

    final nearFuture = _fetchNearIncidents(
      bounds: bounds,
      state: filters.state,
      refresh: refresh,
    );
    final city = area?.city;
    final cityFuture = city != null && city.isNotEmpty
        ? _fetchCityIncidents(
            city: city,
            state: area?.state ?? filters.state,
            refresh: refresh,
          )
        : Future<List<CrimeIncident>>.value(const []);

    final results = await Future.wait([nearFuture, cityFuture]);
    _addIncidents(merged, results[0]);
    _addIncidents(merged, results[1]);

    final resolved = await _geocodeService.resolveCoordinates(merged.values.toList());

    final filtered = resolved
        .where(filters.matches)
        .where(
          (i) =>
              !i.isMappable ||
              bounds.contains(i.latitude!, i.longitude!) ||
              (city != null &&
                  i.suburb?.toLowerCase() == city.toLowerCase()),
        )
        .toList();

    _persistAndCache(
      filtered,
      areaKey: CrimeAreaKeys.viewport(bounds, state: filters.state),
    );
    _saveLastViewport(bounds);

    return filtered;
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
      final incidents = buildDemoIncidents()
          .where(
            (i) => i.suburb?.toLowerCase() == city.toLowerCase(),
          )
          .where(filters.matches)
          .toList();
      _persistAndCache(
        incidents,
        areaKey: CrimeAreaKeys.suburb(city, state),
        suburb: city,
        state: state,
      );
      return incidents;
    }

    final merged = <String, CrimeIncident>{};
    final pageLimit = limit.clamp(1, _pageSize);
    final resolvedState = state;

    final firstPage = await _fetchSuburbPageCached(
      city: city,
      state: resolvedState,
      filters: filters,
      limit: pageLimit,
      offset: offset,
      refresh: refresh,
    );

    for (final incident in firstPage) {
      merged[incident.id] = incident;
    }

    if (firstPage.length >= pageLimit && merged.length < _maxRecords) {
      final remainingOffsets = <int>[];
      var nextOffset = offset + firstPage.length;
      while (remainingOffsets.length < 4 && nextOffset < _maxRecords) {
        remainingOffsets.add(nextOffset);
        nextOffset += pageLimit;
      }

      final pages = await Future.wait(
        remainingOffsets.map(
          (pageOffset) => _fetchSuburbPageCached(
            city: city,
            state: resolvedState,
            filters: filters,
            limit: pageLimit,
            offset: pageOffset,
            refresh: refresh,
          ),
        ),
      );

      for (final page in pages) {
        for (final incident in page) {
          merged[incident.id] = incident;
        }
      }
    }

    final resolved =
        await _geocodeService.resolveCoordinates(merged.values.toList());
    final filtered = resolved.where(filters.matches).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    _persistAndCache(
      filtered,
      areaKey: CrimeAreaKeys.suburb(city, resolvedState),
      suburb: city,
      state: resolvedState,
    );

    return filtered;
  }

  Future<List<CrimeIncident>> _fetchSuburbPageCached({
    required String city,
    String? state,
    required IncidentFilters filters,
    required int limit,
    required int offset,
    required bool refresh,
  }) async {
    final cacheKey = CrimeQueryCache.suburbPageKey(
      city: city,
      state: state,
      limit: limit,
      offset: offset,
    );

    if (!refresh) {
      final cached = _cache.get(cacheKey);
      if (cached != null) return cached;
    }

    final incidents = await _querySuburbPage(
      city: city,
      state: state,
      filters: filters,
      limit: limit,
      offset: offset,
    );
    _cache.put(cacheKey, incidents);
    return incidents;
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

  void _persistAndCache(
    List<CrimeIncident> incidents, {
    required String areaKey,
    String? suburb,
    String? state,
  }) {
    _sessionCache?.putAll(incidents);
    final database = _localDatabase;
    if (database == null) return;

    unawaited(
      database.saveFromIncidents(
        areaKey: areaKey,
        incidents: incidents,
        suburb: suburb,
        state: state,
      ),
    );
  }

  void _saveLastViewport(GeoBounds bounds) {
    final database = _localDatabase;
    if (database == null) return;
    unawaited(database.saveLastViewport(bounds));
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
