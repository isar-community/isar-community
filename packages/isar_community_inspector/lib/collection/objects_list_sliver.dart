import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import 'package:isar_community_inspector/object/isar_object.dart';
import 'package:isar_community_inspector/object/object_view.dart';

class ObjectsListSliver extends StatelessWidget {
  const ObjectsListSliver({
    super.key,
    required this.instance,
    required this.collection,
    required this.schemas,
    required this.objects,
    required this.onUpdate,
    required this.onDelete,
  });

  final String instance;
  final String collection;
  final Map<String, Schema<dynamic>> schemas;
  final List<IsarObject> objects;
  final void Function(
    String collection,
    int id,
    String path,
    dynamic value,
  ) onUpdate;
  final void Function(int id) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collectionSchema = schemas[collection]! as CollectionSchema;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        childCount: objects.length,
        (BuildContext context, int index) {
          final object = objects[index];
          return Card(
            key: Key('object ${object.getValue(collectionSchema.idName)}'),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: ObjectView(
                      schemaName: collection,
                      schemas: schemas,
                      object: object,
                      root: true,
                      onUpdate: (collection, id, path, value) {
                        onUpdate(collection, id!, path, value);
                      },
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.copy_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          tooltip: 'Copy as JSON',
                          visualDensity: VisualDensity.standard,
                          onPressed: () => _copyObject(object),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.standard,
                          onPressed: () {
                            final id = object.getValue(collectionSchema.idName);
                            onDelete(id as int);
                          },
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _copyObject(IsarObject object) {
    final json = Map.of(object.data);
    final schema = schemas[collection]! as CollectionSchema;
    for (final linkName in schema.links.keys) {
      json.remove(linkName);
    }
    Clipboard.setData(ClipboardData(text: jsonEncode(json)));
  }
}
