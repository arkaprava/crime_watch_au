import 'package:crime_watch_au/models/crime_incident.dart';
import 'package:crime_watch_au/services/crime_local_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final occurredAt = DateTime(2026, 3, 1);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CrimeLocalDatabase', () {
    late CrimeLocalDatabase database;

    setUp(() async {
      database = CrimeLocalDatabase(databaseFactory: databaseFactory);
      await database.init(databasePath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await database.close();
    });

    test('persists total count and crime types for an area', () async {
      await database.saveFromIncidents(
        areaKey: 'suburb|balga|WA',
        suburb: 'Balga',
        state: 'WA',
        incidents: [
          CrimeIncident(
            id: '1',
            title: 'Theft',
            type: CrimeType.theft,
            occurredAt: occurredAt,
            offenceCount: 5,
          ),
          CrimeIncident(
            id: '2',
            title: 'Assault',
            type: CrimeType.assault,
            occurredAt: occurredAt,
            offenceCount: 2,
          ),
        ],
      );

      final stats = await database.getAreaStats('suburb|balga|WA');
      expect(stats, isNotNull);
      expect(stats!.totalCount, 7);
      expect(stats.typeCounts[CrimeType.theft], 5);
      expect(stats.typeCounts[CrimeType.assault], 2);
      expect(stats.suburb, 'Balga');
      expect(stats.state, 'WA');
    });

    test('listAreas returns stored areas newest first', () async {
      await database.saveFromIncidents(
        areaKey: 'suburb|balga|WA',
        suburb: 'Balga',
        state: 'WA',
        incidents: [
          CrimeIncident(
            id: '1',
            title: 'Theft',
            type: CrimeType.theft,
            occurredAt: occurredAt,
          ),
        ],
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));

      await database.saveFromIncidents(
        areaKey: 'suburb|armadale|WA',
        suburb: 'Armadale',
        state: 'WA',
        incidents: [
          CrimeIncident(
            id: '2',
            title: 'Assault',
            type: CrimeType.assault,
            occurredAt: occurredAt,
          ),
        ],
      );

      final areas = await database.listAreas();
      expect(areas, hasLength(2));
      expect(areas.first.areaKey, 'suburb|armadale|WA');
    });

    test('saveLastViewport round-trips bounds', () async {
      const bounds = GeoBounds(
        southWestLat: -32.1,
        southWestLng: 115.8,
        northEastLat: -31.9,
        northEastLng: 116.0,
      );

      await database.saveLastViewport(bounds);
      final restored = await database.getLastViewport();

      expect(restored?.southWestLat, bounds.southWestLat);
      expect(restored?.northEastLng, bounds.northEastLng);
    });
  });
}
