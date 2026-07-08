import 'package:flutter_test/flutter_test.dart';

import 'package:crime_watch_au/models/crime_incident.dart';
import 'package:crime_watch_au/models/location_result.dart';

void main() {
  group('CrimeType.fromApi', () {
    test('maps GraphQL enum values', () {
      expect(CrimeType.fromApi('THEFT'), CrimeType.theft);
      expect(CrimeType.fromApi('DRUG_OFFENSE'), CrimeType.drugOffense);
      expect(CrimeType.fromApi('CYBERCRIME'), CrimeType.cybercrime);
    });

    test('falls back to other for unknown values', () {
      expect(CrimeType.fromApi('piracy'), CrimeType.other);
    });

    test('apiValue round-trips schema enums', () {
      expect(CrimeType.theft.apiValue, 'THEFT');
      expect(CrimeType.drugOffense.apiValue, 'DRUG_OFFENSE');
    });
  });

  group('CrimeSeverity.fromApi', () {
    test('maps severity levels', () {
      expect(CrimeSeverity.fromApi('LOW'), CrimeSeverity.low);
      expect(CrimeSeverity.fromApi('CRITICAL'), CrimeSeverity.critical);
    });
  });

  group('CrimeIncident.fromGraphQl', () {
    test('parses nested location and enums', () {
      final incident = CrimeIncident.fromGraphQl({
        'id': 'abc-1',
        'title': 'Break and enter',
        'description': 'Rear window forced',
        'crimeType': 'BURGLARY',
        'severity': 'HIGH',
        'status': 'REPORTED',
        'occurredAt': '2026-06-15T10:30:00Z',
        'location': {
          'city': 'Ultimo',
          'state': 'NSW',
          'country': 'Australia',
          'coordinates': {'latitude': -33.8845, 'longitude': 151.1957},
        },
      });

      expect(incident.id, 'abc-1');
      expect(incident.title, 'Break and enter');
      expect(incident.type, CrimeType.burglary);
      expect(incident.severity, CrimeSeverity.high);
      expect(incident.suburb, 'Ultimo');
      expect(incident.isMappable, isTrue);
      expect(incident.hasExactCoordinates, isTrue);
    });

    test('parses suburb aggregate without coordinates', () {
      final incident = CrimeIncident.fromGraphQl({
        'id': 'agg-1',
        'title': 'Arson in Abbotsford',
        'description': 'Aggregate: 1 offences reported in Mar 1997 (Arson)',
        'crimeType': 'ARSON',
        'severity': 'HIGH',
        'status': 'REPORTED',
        'granularity': 'SUBURB_AGGREGATE',
        'geocodeStatus': 'UNRESOLVED',
        'offenceCount': 1,
        'reportingPeriod': '1997-03',
        'source': 'nsw-bocsar-statistics',
        'occurredAt': '1997-03-31T02:00:00Z',
        'location': {
          'city': 'Abbotsford',
          'state': 'NSW',
          'country': 'Australia',
        },
        'suburbBoundary': {
          'name': 'Abbotsford',
          'state': 'NSW',
        },
      });

      expect(incident.isAggregate, isTrue);
      expect(incident.granularity, RecordGranularity.suburbAggregate);
      expect(incident.geocodeStatus, GeocodeStatus.unresolved);
      expect(incident.offenceCount, 1);
      expect(incident.reportingPeriod, '1997-03');
      expect(incident.isMappable, isFalse);
      expect(incident.suburb, 'Abbotsford');
    });

    test('uses suburb boundary centroid when location lacks coordinates', () {
      final incident = CrimeIncident.fromGraphQl({
        'id': 'agg-2',
        'title': 'Theft in Bondi',
        'crimeType': 'THEFT',
        'severity': 'MEDIUM',
        'status': 'REPORTED',
        'granularity': 'SUBURB_AGGREGATE',
        'geocodeStatus': 'APPROXIMATE',
        'occurredAt': '2020-01-01T00:00:00Z',
        'location': {
          'city': 'Bondi',
          'state': 'NSW',
          'country': 'Australia',
        },
        'suburbBoundary': {
          'name': 'Bondi',
          'state': 'NSW',
          'centroid': {'latitude': -33.8915, 'longitude': 151.2767},
        },
      });

      expect(incident.isMappable, isTrue);
      expect(incident.latitude, closeTo(-33.8915, 0.0001));
      expect(incident.coordinateSource, CoordinateSource.suburbCentroid);
      expect(incident.showsCoordinateDetails, isFalse);
    });

    test('showsCoordinateDetails is true for exact incident locations', () {
      final incident = CrimeIncident.fromGraphQl({
        'id': 'inc-1',
        'title': 'Theft',
        'crimeType': 'THEFT',
        'severity': 'LOW',
        'status': 'REPORTED',
        'granularity': 'INCIDENT',
        'occurredAt': '2020-01-01T00:00:00Z',
        'location': {
          'city': 'Bondi',
          'state': 'NSW',
          'country': 'Australia',
          'coordinates': {'latitude': -33.8915, 'longitude': 151.2767},
        },
      });

      expect(incident.showsCoordinateDetails, isTrue);
    });

    test('withCoordinates preserves aggregate metadata', () {
      final incident = CrimeIncident(
        id: 'x',
        title: 'Arson in Abbotsford',
        type: CrimeType.arson,
        occurredAt: DateTime(1997, 3, 31),
        suburb: 'Abbotsford',
        state: 'NSW',
        granularity: RecordGranularity.suburbAggregate,
        offenceCount: 1,
        reportingPeriod: '1997-03',
      );

      final resolved = incident.withCoordinates(
        -33.85,
        151.13,
        resolvedBy: CoordinateSource.geocodedSuburb,
      );

      expect(resolved.isMappable, isTrue);
      expect(resolved.offenceCount, 1);
      expect(resolved.coordinateSource, CoordinateSource.geocodedSuburb);
      expect(resolved.showsCoordinateDetails, isFalse);
    });
  });

  group('IncidentFilters', () {
    final incident = CrimeIncident(
      id: '1',
      title: 'Theft',
      type: CrimeType.theft,
      latitude: -33.8688,
      longitude: 151.2093,
      occurredAt: DateTime(2026, 6, 15),
    );

    test('empty filters match everything', () {
      expect(const IncidentFilters().matches(incident), isTrue);
    });

    test('type filter excludes other types', () {
      const filters = IncidentFilters(types: {CrimeType.assault});
      expect(filters.matches(incident), isFalse);
    });

    test('date range filter applies', () {
      final filters = IncidentFilters(
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 6, 30),
      );
      expect(filters.matches(incident), isTrue);
    });
  });

  group('GeoBounds', () {
    test('contains points inside the box', () {
      const bounds = GeoBounds(
        southWestLat: -34.0,
        southWestLng: 151.0,
        northEastLat: -33.0,
        northEastLng: 152.0,
      );
      expect(bounds.contains(-33.8688, 151.2093), isTrue);
      expect(bounds.contains(-37.8, 144.9), isFalse);
    });

    test('derives centre and radius for map queries', () {
      const bounds = GeoBounds(
        southWestLat: -34.0,
        southWestLng: 151.0,
        northEastLat: -33.0,
        northEastLng: 152.0,
      );
      expect(bounds.centerLatitude, closeTo(-33.5, 0.001));
      expect(bounds.centerLongitude, closeTo(151.5, 0.001));
      expect(bounds.radiusKm, greaterThan(0));
    });
  });

  group('LocationResult.fromNominatimJson', () {
    test('parses suburb and postcode', () {
      final result = LocationResult.fromNominatimJson({
        'lat': '-33.8915',
        'lon': '151.2767',
        'display_name': 'Bondi Junction, Waverley, NSW, Australia',
        'addresstype': 'suburb',
        'address': {
          'suburb': 'Bondi Junction',
          'postcode': '2022',
          'state': 'New South Wales',
        },
      });

      expect(result.title, 'Bondi Junction');
      expect(result.subtitle, '2022 · NSW');
      expect(result.latitude, closeTo(-33.8915, 0.0001));
      expect(result.longitude, closeTo(151.2767, 0.0001));
      expect(result.isSuburbLike, isTrue);
    });

    test('marks administrative suburb results as suburb-like', () {
      final result = LocationResult.fromNominatimJson({
        'lat': '-33.8930556',
        'lon': '151.2633333',
        'display_name': 'Bondi, NSW, Australia',
        'addresstype': 'suburb',
        'class': 'boundary',
        'type': 'administrative',
        'address': {
          'suburb': 'Bondi',
          'state': 'New South Wales',
          'postcode': '2026',
        },
      });

      expect(result.title, 'Bondi');
      expect(result.isSuburbLike, isTrue);
    });

    test('falls back to display name when suburb is missing', () {
      final result = LocationResult.fromNominatimJson({
        'lat': '-37.8136',
        'lon': '144.9631',
        'display_name': 'Melbourne, Victoria, Australia',
        'address': {'state': 'Victoria'},
      });

      expect(result.title, 'Melbourne');
      expect(result.subtitle, 'VIC');
    });
  });
}
