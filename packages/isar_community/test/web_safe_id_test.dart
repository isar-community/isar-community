@TestOn('vm')

import 'package:isar_community/src/web/isar_web.dart';
import 'package:test/test.dart';

const _maxSafeInteger = 9007199254740991;

void main() {
  group('generateWebSafeId', () {
    test('always positive', () {
      const inputs = [
        0,
        1,
        -1,
        42,
        -42,
        0x7FFFFFFFFFFFFFFF,
        -0x8000000000000000,
      ];

      for (final input in inputs) {
        final result = generateWebSafeId(input);
        expect(result, greaterThan(0), reason: 'input=$input');
      }
    });

    test('always within JS safe integer range', () {
      const inputs = [
        0,
        1,
        -1,
        0x7FFFFFFFFFFFFFFF,
        -0x8000000000000000,
        0xFFFFFFFF,
        0x100000000,
      ];

      for (final input in inputs) {
        final result = generateWebSafeId(input);
        expect(
          result,
          lessThanOrEqualTo(_maxSafeInteger),
          reason: 'input=$input',
        );
      }
    });

    test('deterministic', () {
      for (final input in [0, 42, -1, 0x7FFFFFFFFFFFFFFF]) {
        final first = generateWebSafeId(input);
        final second = generateWebSafeId(input);
        expect(first, equals(second));
      }
    });

    test('zero hash produces 1', () {
      expect(generateWebSafeId(0), equals(1));
    });
  });
}
