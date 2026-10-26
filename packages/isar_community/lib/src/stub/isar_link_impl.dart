// ignore_for_file: public_member_api_docs

import 'package:isar_community/isar.dart';
import 'package:isar_community/src/common/isar_link_base_impl.dart';
import 'package:isar_community/src/common/isar_link_common.dart';
import 'package:isar_community/src/common/isar_links_common.dart';
import 'package:isar_community/src/web/isar_web.dart';

mixin IsarLinkBaseMixin<OBJ> on IsarLinkBaseImpl<OBJ> {
  @override
  Id Function(OBJ obj) get getId => unsupportedOnWeb();

  @override
  Future<void> update({
    Iterable<OBJ> link = const [],
    Iterable<OBJ> unlink = const [],
    bool reset = false,
  }) async =>
      unsupportedOnWeb();

  @override
  void updateSync({
    Iterable<OBJ> link = const [],
    Iterable<OBJ> unlink = const [],
    bool reset = false,
  }) =>
      unsupportedOnWeb();
}

class IsarLinkImpl<OBJ> extends IsarLinkCommon<OBJ>
    with IsarLinkBaseMixin<OBJ> {}

class IsarLinksImpl<OBJ> extends IsarLinksCommon<OBJ>
    with IsarLinkBaseMixin<OBJ> {}
