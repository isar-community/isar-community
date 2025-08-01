import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:isar_community_inspector/object/property_builder.dart';
import 'package:isar_community_inspector/object/property_value.dart';

class PropertyView extends StatelessWidget {
  const PropertyView({
    super.key,
    required this.property,
    required this.value,
    required this.isId,
    required this.isIndexed,
    required this.onUpdate,
  });

  final PropertySchema property;
  final dynamic value;
  final bool isId;
  final bool isIndexed;
  final void Function(dynamic value) onUpdate;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final valueLength =
        // ignore: avoid_dynamic_calls
        value is String || value is List ? '(${value.length})' : '';
    return PropertyBuilder(
      property: property.name,
      underline: isIndexed,
      type: isId ? 'Id' : '${property.type.typeName} $valueLength',
      value: value is List
          ? null
          : property.type.isList
              ? const NullValue()
              : PropertyValue(
                  value,
                  type: property.type,
                  enumMap: property.enumMap,
                  onUpdate: isId ? null : onUpdate,
                ),
      children: [
        if (value is List)
          for (var i = 0; i < value.length; i++)
            PropertyBuilder(
              property: '$i',
              type: property.type.typeName,
              value: PropertyValue(
                value[i],
                type: property.type,
                enumMap: property.enumMap,
                onUpdate: onUpdate,
              ),
            ),
      ],
    );
  }
}

extension TypeName on IsarType {
  String get typeName {
    switch (this) {
      case IsarType.bool:
        return 'bool';
      case IsarType.byte:
        return 'byte';
      case IsarType.int:
        return 'short';
      case IsarType.long:
        return 'int';
      case IsarType.float:
        return 'float';
      case IsarType.double:
        return 'double';
      case IsarType.dateTime:
        return 'DateTime';
      case IsarType.string:
        return 'String';
      case IsarType.object:
        return 'Object';
      case IsarType.boolList:
        return 'List<bool>';
      case IsarType.byteList:
        return 'List<byte>';
      case IsarType.intList:
        return 'List<short>';
      case IsarType.longList:
        return 'List<int>';
      case IsarType.floatList:
        return 'List<float>';
      case IsarType.doubleList:
        return 'List<double>';
      case IsarType.dateTimeList:
        return 'List<DateTime>';
      case IsarType.stringList:
        return 'List<String>';
      case IsarType.objectList:
        return 'List<Object>';
    }
  }
}
