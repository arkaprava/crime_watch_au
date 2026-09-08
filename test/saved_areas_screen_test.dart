import 'package:crime_watch_au/models/area_crime_stats.dart';
import 'package:crime_watch_au/models/crime_incident.dart';
import 'package:crime_watch_au/providers/providers.dart';
import 'package:crime_watch_au/screens/saved_areas_screen.dart';
import 'package:crime_watch_au/services/crime_local_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  Widget wrap(List<AreaCrimeStats> storedAreas) {
    return ProviderScope(
      overrides: [
        crimeLocalDatabaseProvider.overrideWithValue(_NoopDatabase()),
        storedAreaStatsProvider.overrideWith((ref) async => storedAreas),
      ],
      child: const MaterialApp(home: SavedAreasScreen()),
    );
  }

  testWidgets('shows empty state when nothing is stored', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('No saved areas yet'), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep_outlined), findsNothing);
  });

  testWidgets('lists stored areas with totals and a clear action',
      (tester) async {
    final areas = [
      AreaCrimeStats(
        areaKey: 'suburb|bondi|NSW',
        suburb: 'Bondi',
        state: 'NSW',
        totalCount: 12,
        typeCounts: const {CrimeType.theft: 8, CrimeType.assault: 4},
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      AreaCrimeStats(
        areaKey: 'viewport|-33.87|151.21|5.0|',
        totalCount: 3,
        typeCounts: const {CrimeType.vandalism: 3},
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    await tester.pumpWidget(wrap(areas));
    await tester.pumpAndSettle();

    expect(find.text('Bondi, NSW'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Theft · 8'), findsOneWidget);
    expect(find.textContaining('Map area'), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
  });
}

/// Stub database; [SavedAreasScreen] only touches it on delete/clear actions,
/// which these tests do not exercise.
class _NoopDatabase extends CrimeLocalDatabase {
  @override
  Future<void> init({String? databasePath}) async {}

  @override
  Future<void> deleteArea(String areaKey) async {}

  @override
  Future<void> clearAreas() async {}
}
