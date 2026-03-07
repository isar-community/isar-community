// ignore_for_file: implementation_imports

import 'dart:js_interop';

import 'package:isar_community/src/web/open.dart' as isar_web;
import 'package:isar_test/src/isar_web_src.dart';

@JS('eval')
external void _jsEval(JSString code);

Future<void> init() async {
  _jsEval(isarWebSrc.toJS);
  // ignore: invalid_use_of_visible_for_testing_member
  isar_web.doNotInitializeIsarWeb();
}
