import 'package:flutter_test/flutter_test.dart';

import 'package:crime_watch_au/models/crime_incident.dart';
import 'package:crime_watch_au/utils/incident_timeline.dart';

void main() {
  group('groupIncidentsByMonth', () {
    test('groups and sorts incidents newest month first', () {
      final incidents = [
        CrimeIncident(
          id: '1',
          title: 'Older',
          type: CrimeType.theft,
          occurredAt: DateTime(2025, 1, 15),
        ),
        CrimeIncident(
          id: '2',
          title: 'Newer same month',
          type: CrimeType.assault,
          occurredAt: DateTime(2025, 3, 20),
        ),
        CrimeIncident(
          id: '3',
          title: 'Newer month',
          type: CrimeType.burglary,
          occurredAt: DateTime(2025, 3, 5),
        ),
      ];

      final grouped = groupIncidentsByMonth(incidents);

      expect(grouped.keys.toList(), ['2025-03', '2025-01']);
      expect(grouped['2025-03']!.first.id, '2');
      expect(grouped['2025-03']!.last.id, '3');
    });

    test('formatIncidentTimelineLabel uses reporting period for aggregates', () {
      final incident = CrimeIncident(
        id: 'agg-1',
        title: 'Arson aggregate',
        type: CrimeType.arson,
        occurredAt: DateTime(2024, 1, 1),
        granularity: RecordGranularity.suburbAggregate,
        reportingPeriod: '2024-01',
        offenceCount: 3,
      );

      expect(
        formatIncidentTimelineLabel(incident),
        'January 2024 · 1 Jan 2024 – 31 Jan 2024 · 3 offences',
      );
    });

    test('formatMonthHeader renders readable month', () {
      expect(formatMonthHeader('2026-03'), 'March 2026');
    });
  });
}
