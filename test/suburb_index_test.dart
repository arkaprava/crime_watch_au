import 'package:flutter_test/flutter_test.dart';

import 'package:crime_watch_au/models/suburb_entry.dart';
import 'package:crime_watch_au/services/suburb_index.dart';

void main() {
  group('SuburbIndex', () {
    late SuburbIndex index;

    setUp(() {
      index = SuburbIndex.instance;
      index.debugReplaceEntries(const [
        SuburbEntry(name: 'Armatree', state: 'NSW'),
        SuburbEntry(name: 'Armidale', state: 'NSW'),
        SuburbEntry(name: 'Bondi', state: 'NSW'),
        SuburbEntry(name: 'Bondi Junction', state: 'NSW'),
        SuburbEntry(
          name: 'Adelaide',
          state: 'SA',
          postcode: '5000',
          latitude: -34.9285,
          longitude: 138.6007,
        ),
        SuburbEntry(name: 'ARMAGH', state: 'SA', postcode: '5453'),
      ]);
    });

    test('returns only prefix matches for suburb names', () {
      final matches = index.search('Arma');
      expect(matches.map((entry) => entry.name).toList(), ['ARMAGH', 'Armatree']);
      for (final match in matches) {
        expect(match.name.toLowerCase().startsWith('arma'), isTrue);
      }
    });

    test('does not return contains-only matches', () {
      final matches = index.search('Arma');
      expect(matches.any((entry) => entry.name == 'Bondi'), isFalse);
    });

    test('matches postcodes by prefix', () {
      final matches = index.search('500');
      expect(matches, hasLength(1));
      expect(matches.first.name, 'Adelaide');
      expect(matches.first.postcode, '5000');
    });

    test('findExact returns cached suburb with coordinates', () {
      final adelaide = index.findExact('Adelaide', 'SA');
      expect(adelaide?.latitude, closeTo(-34.9285, 0.0001));
      expect(adelaide?.longitude, closeTo(138.6007, 0.0001));
    });

    test('searchAsLocationResults marks suburbs without coordinates', () {
      final results = index.searchAsLocationResults('Armatree');
      expect(results, hasLength(1));
      expect(results.first.needsGeocode, isTrue);
      expect(results.first.isSuburbLike, isTrue);
    });
  });
}
