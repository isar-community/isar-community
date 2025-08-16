import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dartx/dartx.dart';
import 'package:isar_community/isar.dart' as isar;
import 'package:source_gen/source_gen.dart';

const TypeChecker _collectionChecker = TypeChecker.typeNamed(isar.Collection);
const TypeChecker _enumeratedChecker = TypeChecker.typeNamed(isar.Enumerated);
const TypeChecker _embeddedChecker = TypeChecker.typeNamed(isar.Embedded);
const TypeChecker _ignoreChecker = TypeChecker.typeNamed(isar.Ignore);
const TypeChecker _nameChecker = TypeChecker.typeNamed(isar.Name);
const TypeChecker _indexChecker = TypeChecker.typeNamed(isar.Index);
const TypeChecker _backlinkChecker = TypeChecker.typeNamed(isar.Backlink);

extension ClassElementX on ClassElement2 {
  bool get hasZeroArgsConstructor {
    return constructors2.any(
      (ConstructorElement2 c) =>
          c.isPublic &&
          !c.formalParameters.any((FormalParameterElement p) => !p.isOptional),
    );
  }

  List<FieldElement2> get allAccessors {
    final ignoreFields =
        collectionAnnotation?.ignore ?? embeddedAnnotation!.ignore;
    return [
      ...fields2,
      if (collectionAnnotation?.inheritance ?? embeddedAnnotation!.inheritance)
        for (final InterfaceType supertype in allSupertypes) ...[
          if (!supertype.isDartCoreObject)
            ...(supertype.element3 as ClassElement2).fields2,
        ],
    ]
        .where(
          (FieldElement2 e) {
            // Skip non-public and static fields
            if (!e.isPublic || e.isStatic) return false;
            
            // Skip fields in the ignore list
            if (ignoreFields.contains(e.name3)) return false;
            
            // For synthetic fields (created from getters), check the getter for @ignore
            if (e.isSynthetic && e.getter2 != null) {
              if (_ignoreChecker.hasAnnotationOf(e.getter2!)) return false;
            }
            
            // Check if the field itself has @ignore
            if (_ignoreChecker.hasAnnotationOf(e)) return false;
            
            return true;
          }
        )
        .distinctBy((e) => e.name3)
        .toList();
  }

  List<String> get enumConsts {
    return fields2
        .where((e) => e.isEnumConstant)
        .map((e) => e.name3 ?? '')
        .toList();
  }
}

extension PropertyElementX on FieldElement2 {
  bool get isLink {
    final dartType = type;
    if (dartType is InterfaceType) {
      return dartType.element3.name3 == 'IsarLink';
    }
    return false;
  }

  bool get isLinks {
    final dartType = type;
    if (dartType is InterfaceType) {
      return dartType.element3.name3 == 'IsarLinks';
    }
    return false;
  }

  isar.Enumerated? get enumeratedAnnotation {
    final ann = _enumeratedChecker.firstAnnotationOfExact(this);
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
    final ann = _backlinkChecker.firstAnnotationOfExact(this);
    if (ann == null) {
      return null;
    }
    return isar.Backlink(to: ann.getField('to')!.toStringValue()!);
  }

  List<isar.Index> get indexAnnotations {
    return _indexChecker.annotationsOfExact(this).map((DartObject ann) {
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

extension ElementX on Element2 {
  String get isarName {
    final ann = _nameChecker.firstAnnotationOfExact(this);
    late String name;
    if (ann == null) {
      name = name3 ?? '';
    } else {
      name = ann.getField('name')!.toStringValue()!;
    }
    checkIsarName(name, this);
    return name;
  }

  isar.Collection? get collectionAnnotation {
    final ann = _collectionChecker.firstAnnotationOfExact(this);
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

    accessor = (name3 ?? '').decapitalize();
    if (!accessor.endsWith('s')) {
      accessor += 's';
    }

    return accessor;
  }

  isar.Embedded? get embeddedAnnotation {
    final ann = _embeddedChecker.firstAnnotationOfExact(this);
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

void checkIsarName(String name, Element2 element) {
  if (name.isBlank || name.startsWith('_')) {
    err('Names must not be blank or start with "_".', element);
  }
}

Never err(String msg, [Element2? element]) {
  throw InvalidGenerationSourceError(msg, element: element);
}
