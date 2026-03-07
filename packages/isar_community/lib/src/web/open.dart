// ignore_for_file: public_member_api_docs, invalid_use_of_protected_member

import 'dart:async';
import 'dart:js_interop';

import 'package:isar_community/isar.dart';
import 'package:isar_community/src/web/isar_web.dart';
import 'package:meta/meta.dart';
import 'package:web/web.dart' as web;

bool _loaded = false;
Future<void> initializeIsarWeb([String? jsUrl]) async {
  if (_loaded) {
    return;
  }
  _loaded = true;

  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.type = 'text/javascript';
  script.src = 'https://unpkg.com/isar@${Isar.version}/dist/index.js';
  script.async = true;
  web.document.head!.append(script);
  final completer = Completer<void>();
  script.onload = ((web.Event event) {
    completer.complete();
  }).toJS;
  script.onerror = ((web.Event event) {
    completer.completeError(IsarError('Failed to load Isar'));
  }).toJS;
  await completer.future.timeout(
    const Duration(seconds: 30),
    onTimeout: () {
      throw IsarError('Failed to load Isar');
    },
  );
}

@visibleForTesting
void doNotInitializeIsarWeb() {
  _loaded = true;
}

Future<Isar> openIsar({
  required List<CollectionSchema<dynamic>> schemas,
  String? directory,
  required String name,
  required int maxSizeMiB,
  required bool relaxedDurability,
  CompactCondition? compactOnLaunch,
}) async {
  throw IsarError(
    'Please use Isar 2.5.0 if you need web support. '
    'A 3.x version with web support will be released soon.',
  );
  /*await initializeIsarWeb();
  final schemasJson = getSchemas(schemas).map((e) => e.toJson());
  final schemasJs = jsify(schemasJson.toList()) as List<dynamic>;
  final instance = await openIsarJs(name, schemasJs, relaxedDurability)
      .wait<IsarInstanceJs>();
  final isar = IsarImpl(name, instance);
  final cols = <Type, IsarCollection<dynamic>>{};
  for (final schema in schemas) {
    final col = instance.getCollection(schema.name);
    schema.toCollection(<OBJ>() {
      schema as CollectionSchema<OBJ>;
      cols[OBJ] = IsarCollectionImpl<OBJ>(
        isar: isar,
        native: col,
        schema: schema,
      );
    });
  }

  isar.attachCollections(cols);
  return isar;*/
}

Isar openIsarSync({
  required List<CollectionSchema<dynamic>> schemas,
  String? directory,
  required String name,
  required int maxSizeMiB,
  required bool relaxedDurability,
  CompactCondition? compactOnLaunch,
}) =>
    unsupportedOnWeb();
