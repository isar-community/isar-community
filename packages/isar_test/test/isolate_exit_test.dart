@TestOn('vm')
import 'dart:async';
import 'dart:isolate';

import 'package:isar_community/isar.dart';
import 'package:isar_test/isar_test.dart';
import 'package:test/test.dart';

part 'isolate_exit_test.g.dart';

@collection
class Model {
  Id? id;

  late String first;

  late String second;
}

const _rows = 100000;

// Exits while its work is still on the worker pool, the way an isolate that is
// shut down does. Nothing is closed and no transaction is finished.
Future<void> _exit(List<String> args) async {
  testTempPath = args[0];
  final isar = await openTempIsar([ModelSchema], name: args[1]);

  if (args[2] == 'queries') {
    final handedOver = <Future<void>>[];
    for (var i = 0; i < 4; i++) {
      final inside = Completer<void>();
      handedOver.add(inside.future);
      unawaited(
        isar.txn(() async {
          // Inside a transaction the call hands the query to the worker
          // before it returns.
          unawaited(isar.models.where().sortByFirst().thenBySecond().findAll());
          inside.complete();
          await Completer<void>().future;
        }),
      );
    }
    await Future.wait(handedOver);
  } else {
    final inside = Completer<void>();
    unawaited(
      isar.writeTxn(() async {
        await isar.models.put(
          Model()
            ..first = 'orphan'
            ..second = '',
        );
        inside.complete();
        await Completer<void>().future;
      }),
    );
    await inside.future;
  }
  Isolate.exit();
}

// Runs an isolate until it has exited. Unless the database is kept open here,
// that isolate is the only one to have it open.
Future<void> _exitWith(Isar isar, String work, {bool keepOpen = false}) async {
  final name = isar.name;
  final directory = isar.directory!;
  if (!keepOpen) {
    expect(await isar.close(), true);
  }

  final exited = ReceivePort();
  await Isolate.spawn(
    _exit,
    [directory, name, work],
    onExit: exited.sendPort,
    onError: exited.sendPort,
  );
  expect(await exited.first, isNull);
}

void main() {
  isarTestAsync('Isolate exits while queries run', () async {
    final isar = await openTempIsar([ModelSchema], closeAutomatically: false);
    await isar.writeTxn(
      () => isar.models.putAll([
        for (var i = 0; i < _rows; i++)
          Model()
            ..first = 'first-${i * 104729 % _rows}'
            ..second = 'second-${(_rows - i) * 7919 % _rows}',
      ]),
    );
    await _exitWith(isar, 'queries');

    final reopened = await openTempIsar([ModelSchema], name: isar.name);
    await reopened.writeTxn(
      () => reopened.models.put(
        Model()
          ..first = 'after'
          ..second = '',
      ),
    );
    expect(await reopened.models.count(), _rows + 1);
  });

  isarTestAsync('Isolate exits inside a write transaction', () async {
    final isar = await openTempIsar([ModelSchema], closeAutomatically: false);
    await _exitWith(isar, 'write');

    // The transaction of the isolate no longer holds the writer, and what it
    // wrote was not committed.
    final reopened = await openTempIsar([ModelSchema], name: isar.name);
    await reopened.writeTxn(
      () => reopened.models.put(
        Model()
          ..first = 'after'
          ..second = '',
      ),
    );
    final models = await reopened.models.where().findAll();
    expect(models.map((model) => model.first), ['after']);
  });

  isarTestAsync('Isolate exits inside a write transaction, database kept open',
      () async {
    final isar = await openTempIsar([ModelSchema]);
    await _exitWith(isar, 'write', keepOpen: true);

    // The database never closed, and still the transaction of the isolate no
    // longer holds the writer.
    await isar
        .writeTxn(
          () => isar.models.put(
            Model()
              ..first = 'after'
              ..second = '',
          ),
        )
        .timeout(const Duration(seconds: 30));
    final models = await isar.models.where().findAll();
    expect(models.map((model) => model.first), ['after']);
  });
}
