import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:isar_community_inspector/collection/collection_area.dart';
import 'package:isar_community_inspector/connect_client.dart';
import 'package:isar_community_inspector/sidebar.dart';

class ConnectedLayout extends StatefulWidget {
  const ConnectedLayout({
    super.key,
    required this.client,
    required this.instances,
    required this.schemasMap,
  });

  final ConnectClient client;
  final List<String> instances;
  final Map<String, List<CollectionSchema<dynamic>>> schemasMap;

  @override
  State<ConnectedLayout> createState() => _ConnectedLayoutState();
}

class _ConnectedLayoutState extends State<ConnectedLayout> {
  late String selectedInstance;
  late String selectedCollection;
  late StreamSubscription<void> infoSubscription;

  @override
  void initState() {
    _selectInstance(widget.instances.first);
    infoSubscription = widget.client.collectionInfoChanged.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ConnectedLayout oldWidget) {
    if (!widget.instances.contains(selectedInstance)) {
      _selectInstance(widget.instances.first);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    infoSubscription.cancel();
    super.dispose();
  }

  void _selectInstance(String instance) {
    selectedInstance = instance;
    final schemas = widget.schemasMap[instance];
    selectedCollection = schemas != null && schemas.isNotEmpty
        ? schemas.first.name
        : '';
    widget.client.watchInstance(instance);
  }

  @override
  Widget build(BuildContext context) {
    final currentSchemas =
        widget.schemasMap[selectedInstance] ?? <CollectionSchema<dynamic>>[];
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 320,
            child: Sidebar(
              instances: widget.instances,
              selectedInstance: selectedInstance,
              onInstanceSelected: (instance) {
                setState(() {
                  _selectInstance(instance);
                });
              },
              collections: currentSchemas,
              collectionInfo: widget.client.collectionInfo,
              selectedCollection: selectedCollection,
              onCollectionSelected: (collection) {
                setState(() {
                  selectedCollection = collection;
                });
              },
            ),
          ),
          const SizedBox(width: 25),
          Expanded(
            child: CollectionArea(
              key: Key('$selectedInstance.$selectedCollection'),
              instance: selectedInstance,
              collection: selectedCollection,
              client: widget.client,
              schemas: {
                for (final schema in currentSchemas) ...{
                  schema.name: schema,
                  for (final embedded in schema.embeddedSchemas.values) ...{
                    embedded.name: embedded,
                  },
                },
              },
            ),
          ),
        ],
      ),
    );
  }
}
