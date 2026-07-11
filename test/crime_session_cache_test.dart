import 'package:crime_watch_au/models/crime_incident.dart';
import 'package:crime_watch_au/services/crime_session_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final occurredAt = DateTime(2026, 3, 1);

  group('CrimeSessionCache', () {
    test('stores and resolves incident details for the session', () {
      final cache = CrimeSessionCache();
      final summary = CrimeIncident(
        id: 'inc-1',
        title: 'Summary only',
        type: CrimeType.theft,
        occurredAt: occurredAt,
      );
      final detailed = CrimeIncident(
        id: 'inc-1',
        title: 'Full detail',
        type: CrimeType.theft,
        occurredAt: occurredAt,
        description: 'Extended description for the session cache.',
        suburb: 'Balga',
        state: 'WA',
      );

      cache.put(detailed);

      expect(cache.get('inc-1'), detailed);
      expect(cache.resolve(summary).description, detailed.description);
      expect(cache.length, 1);
    });

    test('clear removes all session details', () {
      final cache = CrimeSessionCache();
      cache.putAll([
        CrimeIncident(
          id: '1',
          title: 'A',
          type: CrimeType.theft,
          occurredAt: occurredAt,
        ),
      ]);

      cache.clear();
      expect(cache.length, 0);
      expect(cache.get('1'), isNull);
    });
  });
}
