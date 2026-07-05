// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_test/isar_test.dart';
import 'package:path_provider/path_provider.dart';

import 'all_tests.dart' as tests;

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final completer = Completer<void>();

  group('Integration test', () {
    setUpAll(() async {
      if (!kIsWeb) {
        const envTmp = String.fromEnvironment('ISAR_TEST_TMP');
        if (envTmp.isNotEmpty) {
          await Directory(envTmp).create(recursive: true);
          testTempPath = envTmp;
        } else {
          final dir = await getTemporaryDirectory();
          testTempPath = dir.path;
        }
      }
    });
    tearDownAll(() {
      print('Isar test done');
      completer.complete();
    });

    tests.main();
  });

  testWidgets(
    'Isar',
    (t) async {
      await completer.future;
      expect(testCount > 0, true);
      expect(testErrors, isEmpty);
    },
    timeout: Timeout.none,
  );
}
