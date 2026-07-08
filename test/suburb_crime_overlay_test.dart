import 'package:crime_watch_au/models/crime_incident.dart';
import 'package:crime_watch_au/providers/providers.dart';
import 'package:crime_watch_au/widgets/suburb_crime_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SuburbCrimeOverlay hidden when no active area', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SuburbCrimeOverlay(),
          ),
        ),
      ),
    );

    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });

  testWidgets('SuburbCrimeOverlay shows suburb name and crimes', (tester) async {
    final incidents = [
      CrimeIncident(
        id: '1',
        title: 'Vehicle break-in',
        type: CrimeType.burglary,
        suburb: 'Bondi',
        state: 'NSW',
        occurredAt: DateTime(2026, 3, 10, 14, 30),
        severity: CrimeSeverity.medium,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAreaProvider.overrideWith(_FixedActiveAreaNotifier.new),
          suburbIncidentsProvider.overrideWith(
            (ref) async => incidents,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SuburbCrimeOverlay(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bondi'), findsOneWidget);
    expect(find.text('Vehicle break-in'), findsOneWidget);
    expect(find.text('March 2026'), findsOneWidget);
  });
}

class _FixedActiveAreaNotifier extends ActiveAreaNotifier {
  @override
  ActiveArea? build() => const ActiveArea(city: 'Bondi', state: 'NSW');
}
