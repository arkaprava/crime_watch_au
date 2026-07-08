import 'package:intl/intl.dart';

/// Formats API [reportingPeriod] values into a human-readable duration.
String? formatReportingPeriod(String? period) {
  if (period == null || period.trim().isEmpty) return null;

  final trimmed = period.trim();

  final quarter = RegExp(r'^(\d{4})-Q([1-4])$', caseSensitive: false)
      .firstMatch(trimmed);
  if (quarter != null) {
    final year = int.parse(quarter.group(1)!);
    final q = int.parse(quarter.group(2)!);
    final startMonth = (q - 1) * 3 + 1;
    final endMonth = startMonth + 2;
    final start = DateTime(year, startMonth);
    final end = DateTime(year, endMonth);
    final monthFormat = DateFormat('MMMM');
    if (start.year == end.year) {
      return 'Q$q $year · ${monthFormat.format(start)} – ${monthFormat.format(end)} $year';
    }
    final yearFormat = DateFormat('yyyy');
    return 'Q$q · ${monthFormat.format(start)} ${yearFormat.format(start)} – '
        '${monthFormat.format(end)} ${yearFormat.format(end)}';
  }

  final yearMonth = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(trimmed);
  if (yearMonth != null) {
    final year = int.parse(yearMonth.group(1)!);
    final month = int.parse(yearMonth.group(2)!);
    if (month >= 1 && month <= 12) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0);
      final monthLabel = DateFormat('MMMM yyyy').format(start);
      final dayFormat = DateFormat('d MMM yyyy');
      return '$monthLabel · ${dayFormat.format(start)} – ${dayFormat.format(end)}';
    }
  }

  final financialYear = RegExp(r'^(\d{4})-(\d{2,4})$').firstMatch(trimmed);
  if (financialYear != null) {
    final startYear = int.parse(financialYear.group(1)!);
    var endYear = int.parse(financialYear.group(2)!);
    if (endYear < 100) {
      endYear += 2000;
    }
    return 'Financial year $startYear–${financialYear.group(2)!} · '
        'July $startYear – June $endYear';
  }

  final parsedDate = DateTime.tryParse(trimmed);
  if (parsedDate != null) {
    return DateFormat('d MMM yyyy').format(parsedDate.toLocal());
  }

  return trimmed;
}
