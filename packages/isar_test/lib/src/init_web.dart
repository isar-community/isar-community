// ignore_for_file: avoid_web_libraries_in_flutter
// ignore_for_file: implementation_imports, deprecated_member_use

import 'dart:js' as js;

import 'package:isar_community/src/web/open.dart' as isar_web;
import 'package:isar_test/src/isar_web_src.dart';

Future<void> init() async {
  js.context.callMethod('eval', [isarWebSrc]);
  // ignore: invalid_use_of_visible_for_testing_member
  isar_web.doNotInitializeIsarWeb();
}
