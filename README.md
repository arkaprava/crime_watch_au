# Crime Watch AU

A Flutter app for iOS and Android that shows crime incidents across Australia on a native map (Apple Maps on iOS, Google Maps on Android). Incident data is fetched from a GraphQL service and can be filtered by crime type and date range.

## Features

- Map view with colour-coded markers per crime type, refreshed automatically as you pan/zoom (queries by bounding box, debounced)
- Tap a marker for full incident details (type, severity, location, time, description)
- Filter by crime type and date range
- List view sorted by recency; tapping an item jumps the map to that incident
- Centres on your location when permission is granted (falls back to Sydney)
- Bundled demo data keeps the app fully navigable until a real endpoint is configured

## Configuration

The GraphQL endpoint is supplied at build/run time:

```bash
flutter run \
  --dart-define=GRAPHQL_ENDPOINT=https://your-service.example.com/graphql \
  --dart-define=GRAPHQL_AUTH_TOKEN=optional-bearer-token
```

Until `GRAPHQL_ENDPOINT` is provided, the app serves bundled demo incidents around Sydney so the UI remains testable.

The expected query shape lives in [lib/graphql/incidents_query.dart](lib/graphql/incidents_query.dart):

```graphql
query Incidents($bbox: BBoxInput!, $types: [String!], $from: DateTime, $to: DateTime) {
  incidents(bbox: $bbox, types: $types, from: $from, to: $to) {
    id type description latitude longitude suburb state occurredAt severity
  }
}
```

Adjust the document and `CrimeIncident.fromJson` if your service's schema differs.

### Android: Google Maps API key

Replace `YOUR_GOOGLE_MAPS_API_KEY` in [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) with a real key from the [Google Cloud console](https://developers.google.com/maps/documentation/android-sdk/get-api-key). iOS uses Apple Maps and needs no key.

## Project layout

| Path | Purpose |
|---|---|
| `lib/config/app_config.dart` | Endpoint, auth token, app constants |
| `lib/graphql/` | GraphQL query documents |
| `lib/models/crime_incident.dart` | Incident, filters, and bounds models |
| `lib/repositories/crime_repository.dart` | GraphQL client and data fetching |
| `lib/providers/providers.dart` | Riverpod state (filters, viewport, incidents, location) |
| `lib/screens/` | Map and list screens |
| `lib/widgets/` | Detail sheet, filter bar, marker icon factory |

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # pick an iOS simulator or Android emulator
```

Requires Flutter 3.x, Xcode (for iOS), and the Android SDK with an emulator (for Android).
