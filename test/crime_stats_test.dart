import 'package:crime_watch_au/models/crime_incident.dart';
import 'package:crime_watch_au/utils/crime_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final occurredAt = DateTime(2026, 3, 1);

  group('aggregateTypeCounts', () {
    test('counts incidents as one when offenceCount is null', () {
      final counts = aggregateTypeCounts([
        CrimeIncident(
          id: '1',
          title: 'Theft',
          type: CrimeType.theft,
          occurredAt: occurredAt,
        ),
        CrimeIncident(
          id: '2',
          title: 'Assault',
          type: CrimeType.assault,
          occurredAt: occurredAt,
        ),
      ]);

      expect(counts[CrimeType.theft], 1);
      expect(counts[CrimeType.assault], 1);
    });

    test('uses offenceCount for suburb aggregates', () {
      final counts = aggregateTypeCounts([
        CrimeIncident(
          id: '1',
          title: 'Theft aggregate',
          type: CrimeType.theft,
          occurredAt: occurredAt,
          offenceCount: 12,
        ),
        CrimeIncident(
          id: '2',
          title: 'More theft',
          type: CrimeType.theft,
          occurredAt: occurredAt,
          offenceCount: 3,
        ),
      ]);

      expect(counts[CrimeType.theft], 15);
      expect(aggregateTotalCount([
        CrimeIncident(
          id: '1',
          title: 'Theft aggregate',
          type: CrimeType.theft,
          occurredAt: occurredAt,
          offenceCount: 12,
        ),
        CrimeIncident(
          id: '2',
          title: 'More theft',
          type: CrimeType.theft,
          occurredAt: occurredAt,
          offenceCount: 3,
        ),
      ]), 15);
    });
  });

  group('GeoBounds', () {
    test('supports near query at city zoom', () {
      const bounds = GeoBounds(
        southWestLat: -33.92,
        southWestLng: 151.15,
        northEastLat: -33.82,
        northEastLng: 151.25,
      );

      expect(bounds.supportsNearLocationQuery, isTrue);
    });

    test('skips near query for continental viewport', () {
      const bounds = GeoBounds(
        southWestLat: -44.0,
        southWestLng: 113.0,
        northEastLat: -10.0,
        northEastLng: 154.0,
      );

      expect(bounds.supportsNearLocationQuery, isFalse);
    });
  });

  group('CrimeAreaKeys', () {
    test('suburb key is stable and lowercases city', () {
      expect(CrimeAreaKeys.suburb('Armadale', 'WA'), 'suburb|armadale|WA');
    });

    test('viewport key includes rounded coordinates', () {
      final bounds = GeoBounds(
        southWestLat: -32.0,
        southWestLng: 115.80,
        northEastLat: -31.86,
        northEastLng: 115.92,
      );

      expect(
        CrimeAreaKeys.viewport(bounds, state: 'wa'),
        'viewport|-31.93|115.86|9.6|WA',
      );
    });
  });
}
