import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dartx/dartx.dart';
import 'package:isar_community/isar.dart' as isar;
import 'package:source_gen/source_gen.dart';

final TypeChecker _collectionChecker =
    const TypeChecker.fromRuntime(isar.Collection);
final TypeChecker _enumeratedChecker =
    const TypeChecker.fromRuntime(isar.Enumerated);
final TypeChecker _embeddedChecker =
    const TypeChecker.fromRuntime(isar.Embedded);
final TypeChecker _ignoreChecker = const TypeChecker.fromRuntime(isar.Ignore);
final TypeChecker _nameChecker = const TypeChecker.fromRuntime(isar.Name);
final TypeChecker _indexChecker = const TypeChecker.fromRuntime(isar.Index);
final TypeChecker _backlinkChecker =
    const TypeChecker.fromRuntime(isar.Backlink);

extension ClassElementX on ClassElement {
  bool get hasZeroArgsConstructor {
    return constructors.any(
      (ConstructorElement c) =>
          c.isPublic && !c.formalParameters.any((p) => !p.isOptional),
    );
  }

  List<PropertyInducingElement> get allAccessors {
    final ignoreFields =
        collectionAnnotation?.ignore ?? embeddedAnnotation!.ignore;
    return [
      ...fields,
      if (collectionAnnotation?.inheritance ?? embeddedAnnotation!.inheritance)
        for (final InterfaceType supertype in allSupertypes) ...[
          if (!supertype.isDartCoreObject) ...supertype.element.fields,
        ],
    ]
        .where(
          (PropertyInducingElement e) =>
              e.isPublic &&
              !e.isStatic &&
              !_ignoreChecker.hasAnnotationOf(e.nonSynthetic) &&
              !ignoreFields.contains(e.name),
        )
        .distinctBy((e) => e.name!)
        .toList();
  }

  List<String> get enumConsts {
    return fields.where((e) => e.isEnumConstant).map((e) => e.name!).toList();
  }
}

extension PropertyElementX on PropertyInducingElement {
  bool get isLink => type.element!.name == 'IsarLink';

  bool get isLinks => type.element!.name == 'IsarLinks';

  isar.Enumerated? get enumeratedAnnotation {
    final ann = _enumeratedChecker.firstAnnotationOfExact(nonSynthetic);
    if (ann == null) {
      return null;
    }
    final typeIndex = ann.getField('type')!.getField('index')!.toIntValue()!;
    return isar.Enumerated(
      isar.EnumType.values[typeIndex],
      ann.getField('property')?.toStringValue(),
    );
  }

  isar.Backlink? get backlinkAnnotation {
    final ann = _backlinkChecker.firstAnnotationOfExact(nonSynthetic);
    if (ann == null) {
      return null;
    }
    return isar.Backlink(to: ann.getField('to')!.toStringValue()!);
  }

  List<isar.Index> get indexAnnotations {
    return _indexChecker.annotationsOfExact(nonSynthetic).map((DartObject ann) {
      final rawComposite = ann.getField('composite')!.toListValue();
      final composite = <isar.CompositeIndex>[];
      if (rawComposite != null) {
        for (final c in rawComposite) {
          final indexTypeField = c.getField('type')!;
          isar.IndexType? indexType;
          if (!indexTypeField.isNull) {
            final indexTypeIndex =
                indexTypeField.getField('index')!.toIntValue()!;
            indexType = isar.IndexType.values[indexTypeIndex];
          }
          composite.add(
            isar.CompositeIndex(
              c.getField('property')!.toStringValue()!,
              type: indexType,
              caseSensitive: c.getField('caseSensitive')!.toBoolValue(),
            ),
          );
        }
      }
      final indexTypeField = ann.getField('type')!;
      isar.IndexType? indexType;
      if (!indexTypeField.isNull) {
        final indexTypeIndex = indexTypeField.getField('index')!.toIntValue()!;
        indexType = isar.IndexType.values[indexTypeIndex];
      }
      return isar.Index(
        name: ann.getField('name')!.toStringValue(),
        composite: composite,
        unique: ann.getField('unique')!.toBoolValue()!,
        replace: ann.getField('replace')!.toBoolValue()!,
        type: indexType,
        caseSensitive: ann.getField('caseSensitive')!.toBoolValue(),
      );
    }).toList();
  }
}

extension ElementX on Element {
  String get isarName {
    final ann = _nameChecker.firstAnnotationOfExact(nonSynthetic);
    late String name;
    if (ann == null) {
      name = displayName;
    } else {
      name = ann.getField('name')!.toStringValue()!;
    }
    checkIsarName(name, this);
    return name;
  }

  isar.Collection? get collectionAnnotation {
    final ann = _collectionChecker.firstAnnotationOfExact(nonSynthetic);
    if (ann == null) {
      return null;
    }
    return isar.Collection(
      inheritance: ann.getField('inheritance')!.toBoolValue()!,
      accessor: ann.getField('accessor')!.toStringValue(),
      ignore: ann
          .getField('ignore')!
          .toSetValue()!
          .map((e) => e.toStringValue()!)
          .toSet(),
    );
  }

  String get collectionAccessor {
    var accessor = collectionAnnotation?.accessor;
    if (accessor != null) {
      return accessor;
    }

    accessor = displayName.decapitalize();
    if (!accessor.endsWith('s')) {
      accessor += 's';
    }

    return accessor;
  }

  isar.Embedded? get embeddedAnnotation {
    final ann = _embeddedChecker.firstAnnotationOfExact(nonSynthetic);
    if (ann == null) {
      return null;
    }
    return isar.Embedded(
      inheritance: ann.getField('inheritance')!.toBoolValue()!,
      ignore: ann
          .getField('ignore')!
          .toSetValue()!
          .map((e) => e.toStringValue()!)
          .toSet(),
    );
  }
}

void checkIsarName(String name, Element element) {
  if (name.isBlank || name.startsWith('_')) {
    err('Names must not be blank or start with "_".', element);
  }
}

Never err(String msg, [Element? element]) {
  throw InvalidGenerationSourceError(msg, element: element);
}
