# Crime Watch AU

A Flutter app for iOS and Android that shows crime incidents across Australia on a native map (Apple Maps on iOS, Google Maps on Android). Incident data is fetched from the **Crime Service** GraphQL API and can be filtered by crime type and date range.

## Features

- Map view with colour-coded markers per crime type, refreshed automatically as you pan/zoom (queries by map centre + radius, debounced)
- Tap a marker for full incident details (title, type, severity, location, time, description)
- Filter by crime type and date range
- List view sorted by recency; tapping an item jumps the map to that incident
- Centres on your location when permission is granted (falls back to Sydney)
- Optional bundled demo data for offline UI testing

## Crime Service GraphQL API

The app expects a Crime Service running locally (default **http://127.0.0.1:8080/graphql**).

Key queries used:

- `crimesNearLocation(latitude, longitude, radiusKm, state)` — map viewport fetching (centre + radius derived from visible bounds)
- `crimeIncidents(city, state, crimeType, status, limit, offset)` — available in schema; map uses location query + client-side filters

Crime types match the service enum: `THEFT`, `BURGLARY`, `ROBBERY`, `ASSAULT`, `HOMICIDE`, `KIDNAPPING`, `VANDALISM`, `FRAUD`, `CYBERCRIME`, `DRUG_OFFENSE`, `ARSON`, `OTHER`.

## Running against localhost

Start the Crime Service on port **8080**, then:

```bash
cd ~/Projects/crime_watch_au
flutter run
```

Platform defaults (no `--dart-define` needed):

| Platform | Default endpoint |
|---|---|
| iOS simulator | `http://127.0.0.1:8080/graphql` |
| Android emulator | `http://10.0.2.2:8080/graphql` |
| Physical device | Pass your machine's LAN IP (see below) |

**Physical device** (service on your Mac/PC):

```bash
flutter run --dart-define=GRAPHQL_ENDPOINT=http://192.168.1.10:8080/graphql
```

**Offline demo data** (no Crime Service required):

```bash
flutter run --dart-define=GRAPHQL_USE_DEMO=true
```

API key (sent as `X-API-Key`; defaults to `dev-read-key` for the Crime Service dev profile):

```bash
flutter run --dart-define=GRAPHQL_API_KEY=dev-read-key
```

GraphQL documents live in [lib/graphql/incidents_query.dart](lib/graphql/incidents_query.dart). Response mapping is in `CrimeIncident.fromGraphQl` in [lib/models/crime_incident.dart](lib/models/crime_incident.dart).

### Android: Google Maps API key

Replace `YOUR_GOOGLE_MAPS_API_KEY` in [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) with a real key from the [Google Cloud console](https://developers.google.com/maps/documentation/android-sdk/get-api-key). iOS uses Apple Maps and needs no key.

HTTP cleartext to localhost is enabled for development (`NSAllowsLocalNetworking` on iOS, `usesCleartextTraffic` on Android).

## Project layout

| Path | Purpose |
|---|---|
| `lib/config/app_config.dart` | Endpoint, demo flag, platform localhost defaults |
| `lib/graphql/` | GraphQL query documents |
| `lib/models/crime_incident.dart` | Incident, filters, bounds, enum mapping |
| `lib/repositories/crime_repository.dart` | GraphQL client and `crimesNearLocation` fetching |
| `lib/providers/providers.dart` | Riverpod state (filters, viewport, incidents, location) |
| `lib/screens/` | Map and list screens |
| `lib/widgets/` | Detail sheet, filter bar, marker icon factory |

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Requires Flutter 3.x, Xcode (for iOS), and the Android SDK with an emulator (for Android).
