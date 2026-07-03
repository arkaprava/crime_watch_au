/// GraphQL documents for the crime incident service.
///
/// Written against the assumed schema below; adjust the field names once the
/// real service schema is confirmed:
///
///   type Incident {
///     id: ID!
///     type: String!
///     description: String
///     latitude: Float!
///     longitude: Float!
///     suburb: String
///     state: String
///     occurredAt: DateTime!
///     severity: Int
///   }
const String incidentsQuery = r'''
query Incidents($bbox: BBoxInput!, $types: [String!], $from: DateTime, $to: DateTime) {
  incidents(bbox: $bbox, types: $types, from: $from, to: $to) {
    id
    type
    description
    latitude
    longitude
    suburb
    state
    occurredAt
    severity
  }
}
''';
