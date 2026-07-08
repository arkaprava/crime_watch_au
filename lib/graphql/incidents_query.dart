// GraphQL documents for the Crime Service API.

const String crimeIncidentFields = r'''
fragment CrimeIncidentFields on CrimeIncident {
  id
  title
  description
  crimeType
  severity
  status
  source
  granularity
  geocodeStatus
  offenceCount
  reportingPeriod
  occurredAt
  reportedAt
  location {
    address
    city
    state
    country
    postalCode
    coordinates {
      latitude
      longitude
    }
  }
  suburbBoundary {
    name
    state
    centroid {
      latitude
      longitude
    }
  }
}
''';

const String crimesNearLocationQuery = r'''
query CrimesNearLocation(
  $latitude: Float!
  $longitude: Float!
  $radiusKm: Float!
  $state: String
) {
  crimesNearLocation(
    latitude: $latitude
    longitude: $longitude
    radiusKm: $radiusKm
    state: $state
  ) {
    ...CrimeIncidentFields
  }
}
''';

const String crimeIncidentsQuery = r'''
query CrimeIncidents(
  $city: String
  $state: String
  $crimeType: CrimeType
  $status: CrimeStatus
  $limit: Int
  $offset: Int
) {
  crimeIncidents(
    city: $city
    state: $state
    crimeType: $crimeType
    status: $status
    limit: $limit
    offset: $offset
  ) {
    ...CrimeIncidentFields
  }
}
''';

const String crimesNearLocationDocument =
    '$crimeIncidentFields\n$crimesNearLocationQuery';

const String crimeIncidentsDocument =
    '$crimeIncidentFields\n$crimeIncidentsQuery';
