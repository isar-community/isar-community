import 'package:isar_community/isar.dart';

abstract class MyAbstractClass<T> {
  @ignore
  T get object;
}

@collection
class Model<T> extends MyAbstractClass<T> {
  Id? id;

  @override
  @ignore
  T get object => 'example' as T;
}
