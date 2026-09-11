import 'dart:math';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:isar_community_inspector/connect_client.dart';

class CollectionsList extends StatefulWidget {
  const CollectionsList({
    super.key,
    required this.collections,
    required this.collectionInfo,
    required this.selectedCollection,
    required this.onSelected,
  });

  final List<CollectionSchema<dynamic>> collections;
  final Map<String, ConnectCollectionInfo?> collectionInfo;
  final String? selectedCollection;
  final void Function(String collection) onSelected;

  @override
  State<CollectionsList> createState() => _CollectionsListState();
}

class _CollectionsListState extends State<CollectionsList> {
  String filter = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedCollections =
        List<CollectionSchema<dynamic>>.from(widget.collections)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final filteredCollections = sortedCollections
        .where(
          (c) => c.name.toLowerCase().contains(filter.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            onChanged: (value) {
              setState(() {
                filter = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search table...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            primary: false,
            itemCount: filteredCollections.length,
            itemBuilder: (BuildContext context, int index) {
              final collection = filteredCollections[index];
              final info = widget.collectionInfo[collection.name];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  style: collection.name == widget.selectedCollection
                      ? ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor:
                              theme.colorScheme.onPrimaryContainer,
                        )
                      : null,
                  onPressed: () {
                    widget.onSelected(collection.name);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 25,
                      right: 10,
                      top: 12,
                      bottom: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            collection.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              info?.count.toString() ?? 'loading',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatSize(info?.size ?? 0),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String _formatSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB'];
  final n = (log(bytes) / log(1024)).floor();
  final index = min(n, suffixes.length - 1);
  final value = bytes / pow(1024, index);
  return '${value.toStringAsFixed(index == 0 ? 0 : 2)} ${suffixes[index]}';
}
