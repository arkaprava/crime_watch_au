import 'package:crime_watch_au/utils/reporting_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatReportingPeriod', () {
    test('formats monthly NSW periods as month duration', () {
      expect(
        formatReportingPeriod('1997-03'),
        'March 1997 · 1 Mar 1997 – 31 Mar 1997',
      );
    });

    test('formats quarterly periods', () {
      expect(
        formatReportingPeriod('2025-Q1'),
        'Q1 2025 · January – March 2025',
      );
    });

    test('formats financial year periods', () {
      expect(
        formatReportingPeriod('2024-25'),
        'Financial year 2024–25 · July 2024 – June 2025',
      );
    });

    test('returns null for empty input', () {
      expect(formatReportingPeriod(null), isNull);
      expect(formatReportingPeriod(''), isNull);
    });
  });
}
