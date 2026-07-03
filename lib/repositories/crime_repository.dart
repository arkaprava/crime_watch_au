import 'package:graphql/client.dart';

import '../config/app_config.dart';
import '../data/demo_incidents.dart';
import '../graphql/incidents_query.dart';
import '../models/crime_incident.dart';

/// Fetches crime incidents from the GraphQL service.
///
/// While no real endpoint is configured ([AppConfig.isConfigured] is false)
/// bundled demo data is returned so the app remains fully navigable.
class CrimeRepository {
  CrimeRepository(this._client);

  final GraphQLClient _client;

  Future<List<CrimeIncident>> fetchIncidents({
    required GeoBounds bounds,
    IncidentFilters filters = const IncidentFilters(),
  }) async {
    if (!AppConfig.isConfigured) {
      // Simulate network latency so loading states are visible in the UI.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return buildDemoIncidents()
          .where((i) => bounds.contains(i.latitude, i.longitude))
          .where(filters.matches)
          .toList();
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(incidentsQuery),
        variables: {
          'bbox': bounds.toJson(),
          if (filters.types.isNotEmpty)
            'types': filters.types.map((t) => t.apiValue).toList(),
          if (filters.from != null)
            'from': filters.from!.toUtc().toIso8601String(),
          if (filters.to != null) 'to': filters.to!.toUtc().toIso8601String(),
        },
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final incidents = (result.data?['incidents'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(CrimeIncident.fromJson)
        .toList();
    return incidents;
  }
}

/// Builds the GraphQL client pointed at the configured endpoint.
GraphQLClient createGraphQLClient() {
  final httpLink = HttpLink(AppConfig.graphqlEndpoint);
  Link link = httpLink;
  if (AppConfig.authToken.isNotEmpty) {
    link = AuthLink(getToken: () => 'Bearer ${AppConfig.authToken}')
        .concat(httpLink);
  }
  return GraphQLClient(link: link, cache: GraphQLCache());
}
