import 'package:isar_community/isar.dart';
import 'package:isar_test/isar_test.dart';
import 'package:test/test.dart';

part 'save_links_on_put_test.g.dart';

@collection
class SaveLinkSource {
  SaveLinkSource(this.name);

  Id? id;

  final String name;

  final links = IsarLinks<SaveLinkTarget>();

  @override
  String toString() {
    return 'SaveLinkSource($id, $name)';
  }

  @override
  // ignore: hash_and_equals
  bool operator ==(Object other) {
    return other is SaveLinkSource && id == other.id && other.name == name;
  }
}

@collection
class SaveLinkTarget {
  SaveLinkTarget(this.name);

  Id? id;

  final String name;

  @override
  String toString() {
    return 'SaveLinkTarget($id, $name)';
  }

  @override
  // ignore: hash_and_equals
  bool operator ==(Object other) {
    return other is SaveLinkTarget && id == other.id && other.name == name;
  }
}

void main() {
  group('Save links on put', () {
    late Isar isar;
    late SaveLinkSource source;
    late SaveLinkTarget t1;
    late SaveLinkTarget t2;

    setUp(() async {
      isar = await openTempIsar([SaveLinkSourceSchema, SaveLinkTargetSchema]);

      source = SaveLinkSource('source');
      t1 = SaveLinkTarget('target1');
      t2 = SaveLinkTarget('target2');

      await isar.tWriteTxn(() async {
        await isar.saveLinkTargets.tPutAll([t1, t2]);
      });
    });

    isarTest('.put() with saveLinks saves added links', () async {
      source.links.addAll([t1, t2]);
      await isar.tWriteTxn(() async {
        await isar.saveLinkSources.tPut(source, saveLinks: true);
      });

      final loaded = await isar.saveLinkSources.tGet(source.id!);
      await loaded!.links.tLoad();
      expect(loaded.links, {t1, t2});
    });

    isarTest('.put() without saveLinks does not save links', () async {
      source.links.addAll([t1, t2]);
      await isar.tWriteTxn(() async {
        await isar.saveLinkSources.tPut(source);
      });

      final loaded = await isar.saveLinkSources.tGet(source.id!);
      await loaded!.links.tLoad();
      expect(loaded.links, isEmpty);
    });

    isarTest('.putAll() with saveLinks saves added links', () async {
      final source2 = SaveLinkSource('source2');
      source.links.add(t1);
      source2.links.add(t2);
      await isar.tWriteTxn(() async {
        await isar.saveLinkSources.tPutAll([source, source2], saveLinks: true);
      });

      final loaded1 = await isar.saveLinkSources.tGet(source.id!);
      await loaded1!.links.tLoad();
      expect(loaded1.links, {t1});

      final loaded2 = await isar.saveLinkSources.tGet(source2.id!);
      await loaded2!.links.tLoad();
      expect(loaded2.links, {t2});
    });

    isarTest('.put() with saveLinks saves removed links', () async {
      source.links.addAll([t1, t2]);
      await isar.tWriteTxn(() async {
        await isar.saveLinkSources.tPut(source, saveLinks: true);
      });

      source.links.remove(t1);
      await isar.tWriteTxn(() async {
        await isar.saveLinkSources.tPut(source, saveLinks: true);
      });

      final loaded = await isar.saveLinkSources.tGet(source.id!);
      await loaded!.links.tLoad();
      expect(loaded.links, {t2});
    });
  });
}
