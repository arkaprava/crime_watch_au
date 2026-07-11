import 'package:crime_watch_au/models/crime_incident.dart';
import 'package:crime_watch_au/services/suburb_geocode_service.dart';
import 'package:crime_watch_au/services/suburb_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final occurredAt = DateTime(2026, 3, 1);

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await SuburbIndex.instance.load();
  });

  test('resolveCoordinates uses local suburb index without network calls', () async {
    final service = SuburbGeocodeService(allowNetworkGeocode: false);
    final resolved = await service.resolveCoordinates([
      CrimeIncident(
        id: '1',
        title: 'Balga aggregate',
        type: CrimeType.theft,
        occurredAt: occurredAt,
        suburb: 'Balga',
        state: 'WA',
      ),
      CrimeIncident(
        id: '2',
        title: 'Another Balga aggregate',
        type: CrimeType.assault,
        occurredAt: occurredAt,
        suburb: 'Balga',
        state: 'WA',
      ),
    ]);

    expect(resolved, hasLength(2));
    expect(resolved.every((incident) => incident.isMappable), isTrue);
    expect(
      resolved.every(
        (incident) =>
            incident.coordinateSource == CoordinateSource.geocodedSuburb,
      ),
      isTrue,
    );
  });
}
