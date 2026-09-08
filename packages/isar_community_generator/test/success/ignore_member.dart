import 'package:isar_community/isar.dart';

@collection
class MyObject {
  const MyObject({required this.isarId});

  @ignore
  MyUnknownClass get object => MyUnknownClass();

  final Id? isarId;
}

class MyUnknownClass {}
