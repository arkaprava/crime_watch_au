import 'package:graphql/client.dart';

import '../config/app_config.dart';
import '../data/demo_incidents.dart';
import '../graphql/incidents_query.dart';
import '../models/crime_incident.dart';

/// Fetches crime incidents from the Crime Service GraphQL API.
class CrimeRepository {
  CrimeRepository(this._client);

  final GraphQLClient _client;

  Future<List<CrimeIncident>> fetchIncidents({
    required GeoBounds bounds,
    IncidentFilters filters = const IncidentFilters(),
  }) async {
    if (AppConfig.useDemoData) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return buildDemoIncidents()
          .where((i) => bounds.contains(i.latitude, i.longitude))
          .where(filters.matches)
          .toList();
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(crimesNearLocationDocument),
        variables: {
          'latitude': bounds.centerLatitude,
          'longitude': bounds.centerLongitude,
          'radiusKm': bounds.radiusKm,
          if (filters.state != null) 'state': filters.state,
        },
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final incidents =
        (result.data?['crimesNearLocation'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .map(CrimeIncident.fromGraphQl)
            .where((i) => i.hasCoordinates)
            .where((i) => bounds.contains(i.latitude, i.longitude))
            .where(filters.matches)
            .toList();

    return incidents;
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
