import 'dart:collection';

import 'package:isar_community/isar.dart';
import 'package:isar_community/src/common/isar_link_base_impl.dart';

const bool _kIsWeb = identical(0, 0.0);

/// @nodoc
abstract class IsarLinksCommon<OBJ> extends IsarLinkBaseImpl<OBJ>
    with IsarLinks<OBJ>, SetMixin<OBJ> {
  final _savedObjects = <Id, OBJ>{};

  /// @nodoc
  final addedObjects = HashSet<OBJ>.identity();

  /// @nodoc
  final removedObjects = HashSet<OBJ>.identity();

  final _savedAddedRemovedObjects = HashSet<OBJ>.identity();

  @override
  bool isLoaded = false;

  @override
  bool get isChanged => addedObjects.isNotEmpty || removedObjects.isNotEmpty;

  Map<Id, OBJ> get _loadedObjects {
    if (isAttached && !isLoaded && !_kIsWeb) {
      loadSync();
    }
    return _savedObjects;
  }

  Set<OBJ> get _allObjects {
    if (isAttached && !isLoaded) {
      _computeAllObjectsSet();
    }
    return _savedAddedRemovedObjects;
  }

  @override
  void attach(
    IsarCollection<dynamic> sourceCollection,
    IsarCollection<OBJ> targetCollection,
    String linkName,
    Id? objectId,
  ) {
    super.attach(sourceCollection, targetCollection, linkName, objectId);

    _applyAddedRemoved();
  }

  @override
  Future<void> load({bool overrideChanges = false}) async {
    final objects = await filter().findAll();
    _applyLoaded(objects, overrideChanges);
  }

  @override
  void loadSync({bool overrideChanges = false}) {
    final objects = filter().findAllSync();
    _applyLoaded(objects, overrideChanges);
  }

  void _applyLoaded(List<OBJ> objects, bool overrideChanges) {
    _savedObjects.clear();
    for (final object in objects) {
      final id = getId(object);
      if (id != Isar.autoIncrement) {
        _savedObjects[id] = object;
      }
    }

    if (overrideChanges) {
      addedObjects.clear();
      removedObjects.clear();
    } else {
      _applyAddedRemoved();
    }

    isLoaded = true;

    _computeAllObjectsSet();
  }

  void _applyAddedRemoved() {
    for (final object in addedObjects) {
      final id = getId(object);
      if (id != Isar.autoIncrement) {
        _savedObjects[id] = object;
      }
    }

    for (final object in removedObjects) {
      final id = getId(object);
      if (id != Isar.autoIncrement) {
        _savedObjects.remove(id);
      }
    }
  }

  void _computeAllObjectsSet() {
    _savedAddedRemovedObjects
      ..clear()
      ..addAll(_loadedObjects.values)
      ..removeAll(removedObjects)
      ..addAll(addedObjects);
  }

  @override
  Future<void> save() async {
    if (!isChanged) {
      return;
    }

    await update(link: addedObjects, unlink: removedObjects);

    addedObjects.clear();
    removedObjects.clear();
    isLoaded = true;
  }

  @override
  void saveSync() {
    if (!isChanged) {
      return;
    }

    updateSync(link: addedObjects, unlink: removedObjects);

    addedObjects.clear();
    removedObjects.clear();
    isLoaded = true;
  }

  @override
  Future<void> reset() async {
    await update(reset: true);
    clear();
    isLoaded = true;
  }

  @override
  void resetSync() {
    updateSync(reset: true);
    clear();
    isLoaded = true;
  }

  @override
  bool add(OBJ value) {
    if (isAttached) {
      final id = getId(value);
      if (id != Isar.autoIncrement) {
        if (_savedObjects.containsKey(id)) {
          return false;
        }
        _savedObjects[id] = value;
      }

      removedObjects.removeWhere((obj) => getId(obj) == id);
    } else {
      removedObjects.remove(value);
    }

    final added = addedObjects.add(value);
    if (added) {
      _computeAllObjectsSet();
    }
    return added;
  }

  @override
  bool contains(Object? element) => _allObjects.contains(element);

  @override
  Iterator<OBJ> get iterator => _allObjects.iterator;

  @override
  int get length => _allObjects.length;

  @override
  OBJ? lookup(Object? element) => _allObjects.lookup(element);

  @override
  bool remove(Object? value) {
    if (value is! OBJ) {
      return false;
    }

    if (isAttached) {
      final id = getId(value);
      if (id != Isar.autoIncrement) {
        if (isLoaded && !_savedObjects.containsKey(id)) {
          return false;
        }
        _savedObjects.remove(id);
      }
    }

    final removedAdded = addedObjects.remove(value);
    final removed = removedAdded || removedObjects.add(value);
    if (removed) {
      _computeAllObjectsSet();
    }
    return removed;
  }

  @override
  Set<OBJ> toSet() => _allObjects;

  @override
  void clear() {
    _allObjects.clear();
    _savedObjects.clear();
    addedObjects.clear();
    removedObjects.clear();
  }

  @override
  String toString() {
    final content = IterableBase.iterableToFullString(_allObjects, '{', '}');
    return 'IsarLinks($content)';
  }
}
