// ignore_for_file: public_member_api_docs

import 'dart:ffi';

import 'package:isar_community/isar.dart';
import 'package:isar_community/src/common/isar_link_base_impl.dart';
import 'package:isar_community/src/common/isar_link_common.dart';
import 'package:isar_community/src/common/isar_links_common.dart';
import 'package:isar_community/src/native/isar_collection_impl.dart';
import 'package:isar_community/src/native/isar_core.dart';
import 'package:isar_community/src/native/txn.dart';

mixin IsarLinkBaseMixin<OBJ> on IsarLinkBaseImpl<OBJ> {
  @override
  IsarCollectionImpl<dynamic> get sourceCollection =>
      super.sourceCollection as IsarCollectionImpl;

  @override
  IsarCollectionImpl<OBJ> get targetCollection =>
      super.targetCollection as IsarCollectionImpl<OBJ>;

  late final int linkId = sourceCollection.schema.link(linkName).id;

  @override
  late final getId = targetCollection.schema.getId;

  @override
  Future<void> update({
    Iterable<OBJ> link = const [],
    Iterable<OBJ> unlink = const [],
    bool reset = false,
  }) {
    final linkList = link.toList();
    final unlinkList = unlink.toList();

    final containingId = requireAttached();
    return targetCollection.isar.getTxn(true, (Txn txn) async {
      final count = linkList.length + unlinkList.length;
      final idsPtr = txn.alloc<Int64>(count);
      final ids = idsPtr.asTypedList(count);

      for (var i = 0; i < linkList.length; i++) {
        final object = linkList[i];
        var id = getId(object);

        if (id == Isar.autoIncrement) {
          id = await targetCollection.put(object);
        }

        ids[i] = id;
      }
      for (var i = 0; i < unlinkList.length; i++) {
        ids[linkList.length + i] = requireGetId(unlinkList[i]);
      }

      IC.isar_link_update_all(
        sourceCollection.ptr,
        txn.ptr,
        linkId,
        containingId,
        idsPtr,
        linkList.length,
        unlinkList.length,
        reset,
      );
      await txn.wait();
    });
  }

  @override
  void updateSync({
    Iterable<OBJ> link = const [],
    Iterable<OBJ> unlink = const [],
    bool reset = false,
  }) {
    final containingId = requireAttached();
    targetCollection.isar.getTxnSync(true, (Txn txn) {
      if (reset) {
        nCall(
          IC.isar_link_unlink_all(
            sourceCollection.ptr,
            txn.ptr,
            linkId,
            containingId,
          ),
        );
      }

      for (final object in link) {
        var id = getId(object);
        if (id == Isar.autoIncrement) {
          id = targetCollection.putByIndexSyncInternal(
            txn: txn,
            object: object,
          );
        }

        nCall(
          IC.isar_link(sourceCollection.ptr, txn.ptr, linkId, containingId, id),
        );
      }
      for (final object in unlink) {
        final unlinkId = requireGetId(object);
        nCall(
          IC.isar_link_unlink(
            sourceCollection.ptr,
            txn.ptr,
            linkId,
            containingId,
            unlinkId,
          ),
        );
      }
    });
  }
}

class IsarLinkImpl<OBJ> extends IsarLinkCommon<OBJ>
    with IsarLinkBaseMixin<OBJ> {}

class IsarLinksImpl<OBJ> extends IsarLinksCommon<OBJ>
    with IsarLinkBaseMixin<OBJ> {}
