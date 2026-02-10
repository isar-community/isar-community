import 'dart:convert';
import 'dart:math';

import 'package:isar_community/isar.dart';
import 'package:isar_community_generator/src/object_info.dart';
import 'package:test/test.dart';
import 'package:xxh3/xxh3.dart';

const _maxSafeInteger = 9007199254740991;

ObjectProperty _idProperty() {
  return ObjectProperty(
    dartName: 'id',
    isarName: 'id',
    typeClassName: 'Id',
    isarType: IsarType.long,
    isId: true,
    enumMap: null,
    enumProperty: null,
    defaultEnumElement: null,
    nullable: true,
    elementNullable: false,
    deserialize: PropertyDeser.none,
    assignable: true,
  );
}

void main() {
  group('generateWebSafeId', () {
    group('mathematical properties', () {
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

      test('non-zero for zero input', () {
        final result = generateWebSafeId(0);

        expect(result, equals(1));
      });
    });

    group('edge cases', () {
      test('zero hash produces 1', () {
        final result = generateWebSafeId(0);

        expect(result, equals(1));
      });

      test('negative hash -1', () {
        final result = generateWebSafeId(-1);

        expect(result, equals(9007194959773695));
      });

      test('max positive 0x7FFFFFFFFFFFFFFF', () {
        final result = generateWebSafeId(0x7FFFFFFFFFFFFFFF);

        expect(result, equals(2147483649));
        expect(result, greaterThan(0));
        expect(result, lessThanOrEqualTo(_maxSafeInteger));
      });

      test('highBits == lowBits produces 1 (XOR fold yields 0)', () {
        final result = generateWebSafeId(0x0000000100000001);

        expect(result, equals(1));
      });
    });

    group('golden values (regression)', () {
      test('ObjectInfo.id for known collection names', () {
        final expected = {
          'User': 9007195675771592,
          'Post': 9007197132217442,
          'Comment': 9007199095200855,
          'Tag': 1969073532,
          'Category': 2535392174,
          'Author': 976836051,
          'Session': 3722175761,
          'Token': 708841232,
        };

        for (final entry in expected.entries) {
          final info = ObjectInfo(
            dartName: entry.key,
            isarName: entry.key,
            properties: [_idProperty()],
          );
          final result = info.id;

          expect(result, equals(entry.value),
              reason: 'collection=${entry.key}');
        }
      });

      test('ObjectIndex.id for known index names', () {
        final expected = {
          'email': 9007195762981363,
          'name': 3464444185,
          'createdAt': 9007197399107298,
        };

        for (final entry in expected.entries) {
          final index = ObjectIndex(
            name: entry.key,
            properties: const [],
            unique: false,
            replace: false,
          );
          final result = index.id;

          expect(result, equals(entry.value), reason: 'index=${entry.key}');
        }
      });

      test('ObjectLink.id for known link', () {
        const link = ObjectLink(
          dartName: 'posts',
          isarName: 'posts',
          targetCollectionDartName: 'Post',
          targetCollectionIsarName: 'Post',
          isSingle: false,
        );

        final result = link.id('User');

        expect(result, equals(9007195661268314));
      });
    });

    group('collision resistance', () {
      test('common collection names produce distinct IDs', () {
        final names = [
          'User',
          'Post',
          'Comment',
          'Tag',
          'Category',
          'Author',
          'Session',
          'Token',
        ];

        final uniqueIds =
            names.map((n) => generateWebSafeId(xxh3(utf8.encode(n)))).toSet();

        expect(uniqueIds.length, equals(names.length));
      });
    });

    group('random inputs', () {
      test('1000 random hashes all produce valid IDs', () {
        final rng = Random(42);

        for (var i = 0; i < 1000; i++) {
          final hash = rng.nextInt(1 << 32) - (1 << 31);
          final result = generateWebSafeId(hash);

          expect(result, greaterThan(0), reason: 'hash=$hash');
          expect(
            result,
            lessThanOrEqualTo(_maxSafeInteger),
            reason: 'hash=$hash',
          );
        }
      });
    });
  });
}
