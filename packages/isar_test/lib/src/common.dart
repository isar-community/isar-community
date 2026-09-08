// ignore_for_file: implementation_imports, depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:isar_community/isar.dart';
import 'package:isar_test/src/init_native.dart'
    if (dart.library.html) 'package:isar_test/src/init_web.dart';
import 'package:isar_test/src/sync_async_helper.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_api/src/backend/invoker.dart';

const kIsWeb = identical(0, 0.0);

final testErrors = <String>[];
int testCount = 0;

var _setUp = false;
Future<void> _prepareTest() async {
  if (!_setUp) {
    await init();
    _setUp = true;
  }
}

@isTest
void isarTest(
  String name,
  dynamic Function() body, {
  Timeout? timeout,
  bool skip = false,
}) {
  isarTestSync(name, body, timeout: timeout, skip: skip);
  isarTestAsync(name, body, timeout: timeout, skip: skip);
}

@isTest
void isarTestSync(
  String name,
  dynamic Function() body, {
  Timeout? timeout,
  bool skip = false,
}) {
  if (!kIsWeb) {
    _isarTest(name, true, body, timeout: timeout, skip: skip);
  }
}

@isTest
void isarTestAsync(
  String name,
  dynamic Function() body, {
  Timeout? timeout,
  bool skip = false,
}) {
  _isarTest(name, false, body, timeout: timeout, skip: skip);
}

void _isarTest(
  String name,
  bool syncTest,
  dynamic Function() body, {
  Timeout? timeout,
  bool skip = false,
}) {
  final testName = syncTest ? '$name SYNC' : name;
  test(
    testName,
    () async {
      await runZoned(
        () async {
          try {
            await _prepareTest();
            await body();
            testCount++;
          } catch (e) {
            testErrors.add('$testName: $e');
            rethrow;
          }
        },
        zoneValues: {#syncTest: syncTest},
      );
    },
    timeout: timeout ?? const Timeout(Duration(minutes: 10)),
    skip: skip,
  );
}

@isTest
void isarTestVm(String name, dynamic Function() body) {
  isarTest(name, body, skip: kIsWeb);
}

@isTest
void isarTestWeb(String name, dynamic Function() body) {
  isarTest(name, body, skip: !kIsWeb);
}

String getRandomName() {
  final random = Random().nextInt(pow(2, 32) as int).toString();
  return '${random}_tmp';
}

String? testTempPath;
Future<Isar> openTempIsar(
  List<CollectionSchema<dynamic>> schemas, {
  String? name,
  String? directory,
  int maxSizeMiB = Isar.defaultMaxSizeMiB,
  CompactCondition? compactOnLaunch,
  bool closeAutomatically = true,
}) async {
  await _prepareTest();
  if (!kIsWeb && directory == null && testTempPath == null) {
    // ISAR_TEST_TMP is set via --dart-define in CI to the workspace path,
    // which is guaranteed accessible. Falls back to systemTemp for local runs.
    const envTmp = String.fromEnvironment('ISAR_TEST_TMP');
    if (envTmp.isNotEmpty) {
      testTempPath = envTmp;
    } else {
      final tempDir = await Directory.systemTemp.createTemp('isar_test_');
      testTempPath = tempDir.path;
    }
    await Directory(testTempPath!).create(recursive: true);
    try {
      await File('/tmp/isar_diag.txt').writeAsString(
        'path=$testTempPath\nexists=${await Directory(testTempPath!).exists()}\n',
      );
    } catch (_) {}
  }

  final isar = await tOpen(
    schemas: schemas,
    name: name ?? getRandomName(),
    maxSizeMiB: maxSizeMiB,
    directory: testTempPath ?? '',
    compactOnLaunch: compactOnLaunch,
  );

  if (Invoker.current != null && closeAutomatically) {
    addTearDown(() async {
      if (isar.isOpen) {
        await isar.close(deleteFromDisk: true);
      }
    });
  }

  // ignore: invalid_use_of_visible_for_testing_member
  if (!kIsWeb) await isar.verify();
  return isar;
}
