import '../repositories/crime_repository.dart';
import 'crime_local_database.dart';
import 'crime_session_cache.dart';

/// Refreshes persisted crime statistics when the app opens.
class CrimeDataSyncService {
  CrimeDataSyncService({
    required CrimeRepository repository,
    required CrimeLocalDatabase database,
    required CrimeSessionCache sessionCache,
    this.maxConcurrentRefreshes = 2,
  })  : _repository = repository,
        _database = database,
        _sessionCache = sessionCache;

  final CrimeRepository _repository;
  final CrimeLocalDatabase _database;
  final CrimeSessionCache _sessionCache;
  final int maxConcurrentRefreshes;

  bool _hasSyncedThisSession = false;

  bool get hasSyncedThisSession => _hasSyncedThisSession;

  /// Updates stored suburbs and the last viewport in the background.
  ///
  /// Runs with limited concurrency so it does not compete with the user's
  /// first map fetch.
  Future<void> refreshOnLaunch() async {
    if (_hasSyncedThisSession) return;
    _hasSyncedThisSession = true;

    await Future<void>.delayed(const Duration(seconds: 2));

    final suburbAreas = (await _database.listAreas())
        .where((area) => area.isSuburb)
        .toList();

    await _refreshInBatches(
      suburbAreas.map((area) {
        final parts = area.areaKey.split('|');
        final city = parts.length > 1 ? parts[1] : '';
        final state = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
        return _RefreshTask.suburb(city: city, state: state);
      }).where((task) => task.city.isNotEmpty),
    );

    final lastViewport = await _database.getLastViewport();
    if (lastViewport != null && lastViewport.supportsNearLocationQuery) {
      try {
        final incidents = await _repository.fetchIncidents(
          bounds: lastViewport,
          refresh: true,
        );
        _sessionCache.putAll(incidents);
      } catch (_) {
        // Keep the last persisted counts when the network is unavailable.
      }
    }
  }

  Future<void> _refreshInBatches(Iterable<_RefreshTask> tasks) async {
    final queue = List<_RefreshTask>.from(tasks);
    while (queue.isNotEmpty) {
      final batch = queue
          .take(maxConcurrentRefreshes)
          .toList(growable: false);
      queue.removeRange(0, batch.length);

      await Future.wait(
        batch.map((task) async {
          try {
            final incidents = await _repository.fetchSuburbIncidents(
              city: task.city,
              state: task.state,
              refresh: true,
            );
            _sessionCache.putAll(incidents);
          } catch (_) {
            // Keep the last persisted counts when the network is unavailable.
          }
        }),
      );
    }
  }
}

class _RefreshTask {
  const _RefreshTask._({required this.city, this.state});

  factory _RefreshTask.suburb({required String city, String? state}) {
    return _RefreshTask._(city: city, state: state);
  }

  final String city;
  final String? state;
}
