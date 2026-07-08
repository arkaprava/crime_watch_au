import 'package:crime_watch_au/models/crime_incident.dart';
import 'package:crime_watch_au/services/crime_query_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final occurredAt = DateTime(2026, 3, 1);

  group('CrimeQueryCache', () {
    test('returns cached incidents before TTL expires', () {
      final cache = CrimeQueryCache(ttl: const Duration(minutes: 5));
      final incidents = [
        CrimeIncident(
          id: '1',
          title: 'Test',
          type: CrimeType.theft,
          occurredAt: occurredAt,
        ),
      ];

      cache.put('key', incidents);
      expect(cache.get('key'), incidents);
    });

    test('expires entries after TTL', () async {
      final cache = CrimeQueryCache(ttl: const Duration(milliseconds: 20));
      cache.put('key', [
        CrimeIncident(
          id: '1',
          title: 'Test',
          type: CrimeType.theft,
          occurredAt: occurredAt,
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(cache.get('key'), isNull);
    });

    test('invalidateSuburb clears all pages for a suburb', () {
      final cache = CrimeQueryCache();
      cache.put(
        CrimeQueryCache.suburbPageKey(
          city: 'Balga',
          state: 'WA',
          limit: 200,
          offset: 0,
        ),
        [
          CrimeIncident(
            id: '1',
            title: 'A',
            type: CrimeType.theft,
            occurredAt: occurredAt,
          ),
        ],
      );

      cache.invalidateSuburb('Balga', 'WA');
      expect(
        cache.get(
          CrimeQueryCache.suburbPageKey(
            city: 'Balga',
            state: 'WA',
            limit: 200,
            offset: 0,
          ),
        ),
        isNull,
      );
    });

    test('nearKey rounds coordinates for stable cache hits', () {
      expect(
        CrimeQueryCache.nearKey(
          latitude: -31.861234,
          longitude: 115.839876,
          radiusKm: 12.34,
          state: 'wa',
        ),
        'near|-31.86|115.84|12.3|WA',
      );
    });
  });
}
