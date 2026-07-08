import 'package:flutter_test/flutter_test.dart';

import 'package:crime_watch_au/services/suburb_index.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled suburb asset', () {
    setUp(() async {
      await SuburbIndex.instance.load();
    });

    test('Balga is Western Australia, not South Australia', () {
      final wa = SuburbIndex.instance.findExact('BALGA', 'WA');
      expect(wa, isNotNull);
      expect(wa!.postcode, '6061');
      expect(SuburbIndex.instance.findExact('BALGA', 'SA'), isNull);

      final matches = SuburbIndex.instance.search('Balga');
      expect(matches.any((entry) => entry.name == 'Balga' && entry.state == 'WA'), isTrue);
      expect(matches.any((entry) => entry.state == 'SA'), isFalse);
    });

    test('Armadale appears for WA and VIC', () {
      final matches = SuburbIndex.instance.search('Armadale');
      expect(matches.length, greaterThanOrEqualTo(2));
      expect(matches.map((entry) => entry.state).toSet(), containsAll(['WA', 'VIC']));
      expect(
        matches.any((entry) => entry.name == 'Armadale' && entry.state == 'WA'),
        isTrue,
      );
    });
  });
}
