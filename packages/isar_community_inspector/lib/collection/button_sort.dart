import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

class SortButtons extends StatelessWidget {
  const SortButtons({
    required this.properties,
    required this.property,
    required this.asc,
    required this.onChanged,
    super.key,
  });

  final List<PropertySchema> properties;
  final String property;
  final bool asc;
  final void Function(String property, bool asc) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Sort results by this property',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isDense: true,
              items: [
                for (final property in properties)
                  if (property.type != IsarType.object && !property.type.isList)
                    DropdownMenuItem(
                      value: property.name,
                      child: Text(property.name),
                    ),
              ],
              value: property,
              onChanged: (value) {
                if (value != null) {
                  onChanged(value, asc);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        ActionChip(
          label: Text(asc ? 'Asc' : 'Desc'),
          onPressed: () {
            onChanged(property, !asc);
          },
          tooltip: 'Toggle sort order',
        ),
      ],
    );
  }
}
