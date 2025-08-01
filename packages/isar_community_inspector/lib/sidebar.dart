import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:isar_community_inspector/collections_list.dart';
import 'package:isar_community_inspector/connect_client.dart';
import 'package:isar_community_inspector/instance_selector.dart';
import 'package:isar_community_inspector/main.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.instances,
    required this.selectedInstance,
    required this.onInstanceSelected,
    required this.collections,
    required this.collectionInfo,
    required this.selectedCollection,
    required this.onCollectionSelected,
  });

  final List<String> instances;
  final String selectedInstance;
  final void Function(String instance) onInstanceSelected;

  final List<CollectionSchema<dynamic>> collections;
  final Map<String, ConnectCollectionInfo?> collectionInfo;
  final String? selectedCollection;
  final void Function(String instance) onCollectionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 80,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 40,
                  ),
                  const SizedBox(width: 15),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Isar',
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Inspector',
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    padding: const EdgeInsets.all(20),
                    icon: Icon(
                      theme.brightness == Brightness.light
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                    ),
                    onPressed: DarkMode.of(context).toggle,
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: CollectionsList(
                collections: collections,
                collectionInfo: collectionInfo,
                selectedCollection: selectedCollection,
                onSelected: onCollectionSelected,
              ),
            ),
          ),
          const SizedBox(height: 12),
          InstanceSelector(
            instances: instances,
            selectedInstance: selectedInstance,
            onSelected: onInstanceSelected,
          ),
        ],
      ),
    );
  }
}
