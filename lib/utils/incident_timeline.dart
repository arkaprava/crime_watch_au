import 'package:intl/intl.dart';

import '../models/crime_incident.dart';

/// Groups incidents into month buckets for timeline display.
Map<String, List<CrimeIncident>> groupIncidentsByMonth(
  List<CrimeIncident> incidents,
) {
  final grouped = <String, List<CrimeIncident>>{};
  for (final incident in incidents) {
    final key = _monthKey(incident);
    grouped.putIfAbsent(key, () => []).add(incident);
  }

  for (final list in grouped.values) {
    list.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) => b.compareTo(a));
  return {for (final key in sortedKeys) key: grouped[key]!};
}

/// Human-readable month header, e.g. "March 2026".
String formatMonthHeader(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return monthKey;
  return DateFormat('MMMM yyyy').format(DateTime(year, month));
}

/// Timeline label for an incident row.
String formatIncidentTimelineLabel(CrimeIncident incident) {
  if (incident.granularity == RecordGranularity.suburbAggregate) {
    final period = incident.reportingPeriodLabel;
    if (period != null) {
      final count = incident.offenceCount;
      if (count != null) {
        return '$period · $count offence${count == 1 ? '' : 's'}';
      }
      return period;
    }
  }
  if (incident.isAggregate && incident.reportingPeriod != null) {
    final count = incident.offenceCount;
    final period = incident.reportingPeriodLabel ?? incident.reportingPeriod!;
    if (count != null) {
      return '$period · $count offence${count == 1 ? '' : 's'}';
    }
    return period;
  }
  return DateFormat('EEE d MMM yyyy, h:mm a')
      .format(incident.occurredAt.toLocal());
}

String _monthKey(CrimeIncident incident) {
  final date = incident.occurredAt.toLocal();
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';
}
