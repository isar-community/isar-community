import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:isar_community_inspector/connect_client.dart';
import 'package:isar_community_inspector/connected_layout.dart';
import 'package:isar_community_inspector/error_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key, required this.port, required this.secret});

  final String port;
  final String secret;

  @override
  State<ConnectionScreen> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionScreen> {
  late Future<ConnectClient> clientFuture;

  @override
  void initState() {
    clientFuture = ConnectClient.connect(widget.port, widget.secret);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ConnectionScreen oldWidget) {
    if (oldWidget.port != widget.port || oldWidget.secret != widget.secret) {
      clientFuture = ConnectClient.connect(widget.port, widget.secret);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConnectClient>(
      future: clientFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _SchemaLoader(client: snapshot.data!);
        } else if (snapshot.hasError) {
          return const ErrorScreen();
        } else {
          return const Loading();
        }
      },
    );
  }
}

class _SchemaLoader extends StatefulWidget {
  const _SchemaLoader({required this.client});

  final ConnectClient client;

  @override
  State<_SchemaLoader> createState() => _SchemaLoaderState();
}

class _SchemaLoaderState extends State<_SchemaLoader> {
  late Future<List<String>> instancesFuture;
  late Future<Map<String, List<CollectionSchema<dynamic>>>> schemasFuture;
  late StreamSubscription<void> _instancesSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _instancesSubscription = widget.client.instancesChanged.listen((event) {
      if (mounted) {
        setState(() {
          _loadData();
        });
      }
    });
  }

  void _loadData() {
    instancesFuture = widget.client.listInstances();
    schemasFuture = instancesFuture.then((instances) async {
      final map = <String, List<CollectionSchema<dynamic>>>{};
      for (final instance in instances) {
        map[instance] = await widget.client.getSchema(instance);
      }
      return map;
    });
  }

  @override
  void didUpdateWidget(covariant _SchemaLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadData();
  }

  @override
  void dispose() {
    _instancesSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([instancesFuture, schemasFuture]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ConnectedLayout(
            client: widget.client,
            instances: snapshot.data![0] as List<String>,
            schemasMap:
                snapshot.data![1]
                    as Map<String, List<CollectionSchema<dynamic>>>,
          );
        } else if (snapshot.hasError) {
          return const ErrorScreen();
        } else {
          return const Loading();
        }
      },
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
