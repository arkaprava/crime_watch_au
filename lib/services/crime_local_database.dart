import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/area_crime_stats.dart';
import '../models/crime_incident.dart';
import '../utils/crime_stats.dart';

/// SQLite store for crime counts and types by area.
class CrimeLocalDatabase {
  CrimeLocalDatabase({DatabaseFactory? databaseFactory})
      : _databaseFactory = databaseFactory;

  final DatabaseFactory? _databaseFactory;
  Database? _db;

  Future<void> init({String? databasePath}) async {
    if (_db != null) return;

    final factory = _databaseFactory ?? databaseFactory;
    final path = databasePath ?? await _defaultDatabasePath();

    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE areas (
              area_key TEXT PRIMARY KEY,
              suburb TEXT,
              state TEXT,
              total_count INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE type_counts (
              area_key TEXT NOT NULL,
              crime_type TEXT NOT NULL,
              count INTEGER NOT NULL,
              PRIMARY KEY (area_key, crime_type),
              FOREIGN KEY (area_key) REFERENCES areas(area_key) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE app_metadata (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      ),
    );
  }

  Future<String> _defaultDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'crime_watch_local.db');
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('CrimeLocalDatabase.init() must be called first');
    }
    return db;
  }

  Future<void> upsertAreaStats({
    required String areaKey,
    required int totalCount,
    required Map<CrimeType, int> typeCounts,
    String? suburb,
    String? state,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = _database;

    await db.transaction((txn) async {
      await txn.insert(
        'areas',
        {
          'area_key': areaKey,
          'suburb': suburb,
          'state': state,
          'total_count': totalCount,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        'type_counts',
        where: 'area_key = ?',
        whereArgs: [areaKey],
      );

      for (final entry in typeCounts.entries) {
        if (entry.value <= 0) continue;
        await txn.insert(
          'type_counts',
          {
            'area_key': areaKey,
            'crime_type': entry.key.apiValue,
            'count': entry.value,
          },
        );
      }
    });
  }

  Future<void> saveFromIncidents({
    required String areaKey,
    required List<CrimeIncident> incidents,
    String? suburb,
    String? state,
  }) {
    return upsertAreaStats(
      areaKey: areaKey,
      totalCount: aggregateTotalCount(incidents),
      typeCounts: aggregateTypeCounts(incidents),
      suburb: suburb,
      state: state,
    );
  }

  Future<AreaCrimeStats?> getAreaStats(String areaKey) async {
    final rows = await _database.query(
      'areas',
      where: 'area_key = ?',
      whereArgs: [areaKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final typeRows = await _database.query(
      'type_counts',
      where: 'area_key = ?',
      whereArgs: [areaKey],
    );

    final typeCounts = <CrimeType, int>{};
    for (final typeRow in typeRows) {
      final type = CrimeType.fromApi(typeRow['crime_type'] as String);
      typeCounts[type] = typeRow['count'] as int;
    }

    return AreaCrimeStats(
      areaKey: areaKey,
      suburb: row['suburb'] as String?,
      state: row['state'] as String?,
      totalCount: row['total_count'] as int,
      typeCounts: typeCounts,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  Future<List<AreaCrimeStats>> listAreas() async {
    final rows = await _database.query('areas', orderBy: 'updated_at DESC');
    final results = <AreaCrimeStats>[];

    for (final row in rows) {
      final areaKey = row['area_key'] as String;
      final stats = await getAreaStats(areaKey);
      if (stats != null) results.add(stats);
    }
    return results;
  }

  Future<void> saveLastViewport(GeoBounds bounds) async {
    await _database.insert(
      'app_metadata',
      {
        'key': 'last_viewport',
        'value': [
          bounds.southWestLat,
          bounds.southWestLng,
          bounds.northEastLat,
          bounds.northEastLng,
        ].join('|'),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<GeoBounds?> getLastViewport() async {
    final rows = await _database.query(
      'app_metadata',
      where: 'key = ?',
      whereArgs: ['last_viewport'],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final parts = (rows.first['value'] as String).split('|');
    if (parts.length != 4) return null;

    return GeoBounds(
      southWestLat: double.parse(parts[0]),
      southWestLng: double.parse(parts[1]),
      northEastLat: double.parse(parts[2]),
      northEastLng: double.parse(parts[3]),
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
