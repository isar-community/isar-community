// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAssetCollection on Isar {
  IsarCollection<Asset> get assets => this.collection();
}

const AssetSchema = CollectionSchema(
  name: r'Asset',
  id: -2933289051367723566,
  properties: {
    r'content': PropertySchema(id: 0, name: r'content', type: IsarType.string),
    r'kind': PropertySchema(
      id: 1,
      name: r'kind',
      type: IsarType.byte,
      enumMap: _AssetkindEnumValueMap,
    ),
    r'package': PropertySchema(id: 2, name: r'package', type: IsarType.string),
    r'version': PropertySchema(id: 3, name: r'version', type: IsarType.string),
  },

  estimateSize: _assetEstimateSize,
  serialize: _assetSerialize,
  deserialize: _assetDeserialize,
  deserializeProp: _assetDeserializeProp,
  idName: r'id',
  indexes: {
    r'package_version_kind': IndexSchema(
      id: 486865644163081160,
      name: r'package_version_kind',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'package',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'version',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'kind',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _assetGetId,
  getLinks: _assetGetLinks,
  attach: _assetAttach,
  version: '3.2.0-dev.1',
);

int _assetEstimateSize(
  Asset object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.content.length * 3;
  bytesCount += 3 + object.package.length * 3;
  bytesCount += 3 + object.version.length * 3;
  return bytesCount;
}

void _assetSerialize(
  Asset object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.content);
  writer.writeByte(offsets[1], object.kind.index);
  writer.writeString(offsets[2], object.package);
  writer.writeString(offsets[3], object.version);
}

Asset _assetDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Asset(
    content: reader.readString(offsets[0]),
    kind:
        _AssetkindValueEnumMap[reader.readByteOrNull(offsets[1])] ??
        AssetKind.readme,
    package: reader.readString(offsets[2]),
    version: reader.readString(offsets[3]),
  );
  object.id = id;
  return object;
}

P _assetDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (_AssetkindValueEnumMap[reader.readByteOrNull(offset)] ??
              AssetKind.readme)
          as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _AssetkindEnumValueMap = {'readme': 0, 'changelog': 1};
const _AssetkindValueEnumMap = {0: AssetKind.readme, 1: AssetKind.changelog};

Id _assetGetId(Asset object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _assetGetLinks(Asset object) {
  return [];
}

void _assetAttach(IsarCollection<dynamic> col, Id id, Asset object) {
  object.id = id;
}

extension AssetByIndex on IsarCollection<Asset> {
  Future<Asset?> getByPackageVersionKind(
    String package,
    String version,
    AssetKind kind,
  ) {
    return getByIndex(r'package_version_kind', [package, version, kind]);
  }

  Asset? getByPackageVersionKindSync(
    String package,
    String version,
    AssetKind kind,
  ) {
    return getByIndexSync(r'package_version_kind', [package, version, kind]);
  }

  Future<bool> deleteByPackageVersionKind(
    String package,
    String version,
    AssetKind kind,
  ) {
    return deleteByIndex(r'package_version_kind', [package, version, kind]);
  }

  bool deleteByPackageVersionKindSync(
    String package,
    String version,
    AssetKind kind,
  ) {
    return deleteByIndexSync(r'package_version_kind', [package, version, kind]);
  }

  Future<List<Asset?>> getAllByPackageVersionKind(
    List<String> packageValues,
    List<String> versionValues,
    List<AssetKind> kindValues,
  ) {
    final len = packageValues.length;
    assert(
      versionValues.length == len && kindValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([packageValues[i], versionValues[i], kindValues[i]]);
    }

    return getAllByIndex(r'package_version_kind', values);
  }

  List<Asset?> getAllByPackageVersionKindSync(
    List<String> packageValues,
    List<String> versionValues,
    List<AssetKind> kindValues,
  ) {
    final len = packageValues.length;
    assert(
      versionValues.length == len && kindValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([packageValues[i], versionValues[i], kindValues[i]]);
    }

    return getAllByIndexSync(r'package_version_kind', values);
  }

  Future<int> deleteAllByPackageVersionKind(
    List<String> packageValues,
    List<String> versionValues,
    List<AssetKind> kindValues,
  ) {
    final len = packageValues.length;
    assert(
      versionValues.length == len && kindValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([packageValues[i], versionValues[i], kindValues[i]]);
    }

    return deleteAllByIndex(r'package_version_kind', values);
  }

  int deleteAllByPackageVersionKindSync(
    List<String> packageValues,
    List<String> versionValues,
    List<AssetKind> kindValues,
  ) {
    final len = packageValues.length;
    assert(
      versionValues.length == len && kindValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([packageValues[i], versionValues[i], kindValues[i]]);
    }

    return deleteAllByIndexSync(r'package_version_kind', values);
  }

  Future<Id> putByPackageVersionKind(Asset object) {
    return putByIndex(r'package_version_kind', object);
  }

  Id putByPackageVersionKindSync(Asset object, {bool saveLinks = true}) {
    return putByIndexSync(
      r'package_version_kind',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByPackageVersionKind(List<Asset> objects) {
    return putAllByIndex(r'package_version_kind', objects);
  }

  List<Id> putAllByPackageVersionKindSync(
    List<Asset> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'package_version_kind',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension AssetQueryWhereSort on QueryBuilder<Asset, Asset, QWhere> {
  QueryBuilder<Asset, Asset, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AssetQueryWhere on QueryBuilder<Asset, Asset, QWhereClause> {
  QueryBuilder<Asset, Asset, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> packageEqualToAnyVersionKind(
    String package,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'package_version_kind',
          value: [package],
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> packageNotEqualToAnyVersionKind(
    String package,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'package_version_kind',
                lower: [],
                upper: [package],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'package_version_kind',
                lower: [package],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'package_version_kind',
                lower: [package],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'package_version_kind',
                lower: [],
                upper: [package],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> packageVersionEqualToAnyKind(
    String package,
    String version,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'package_version_kind',
          value: [package, version],
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause>
  packageEqualToVersionNotEqualToAnyKind(String package, String version) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'package_version_kind',
                lower: [package],
                upper: [package, version],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'package_version_kind',
                lower: [package, version],
                includeLower: false,
                upper: [package],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'package_version_kind',
                lower: [package, version],
                includeLower: false,
                upper: [package],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'package_version_kind',
                lower: [package],
                upper: [package, version],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> packageVersionKindEqualTo(
    String package,
    String version,
    AssetKind kind,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'package_version_kind',
          value: [package, version, kind],
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause>
  packageVersionEqualToKindNotEqualTo(
    String package,
    String version,
    AssetKind kind,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'package_version_kind',
                lower: [package, version],
                upper: [package, version, kind],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'package_version_kind',
                lower: [package, version, kind],
                includeLower: false,
                upper: [package, version],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'package_version_kind',
                lower: [package, version, kind],
                includeLower: false,
                upper: [package, version],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'package_version_kind',
                lower: [package, version],
                upper: [package, version, kind],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause>
  packageVersionEqualToKindGreaterThan(
    String package,
    String version,
    AssetKind kind, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'package_version_kind',
          lower: [package, version, kind],
          includeLower: include,
          upper: [package, version],
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause>
  packageVersionEqualToKindLessThan(
    String package,
    String version,
    AssetKind kind, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'package_version_kind',
          lower: [package, version],
          upper: [package, version, kind],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause>
  packageVersionEqualToKindBetween(
    String package,
    String version,
    AssetKind lowerKind,
    AssetKind upperKind, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'package_version_kind',
          lower: [package, version, lowerKind],
          includeLower: includeLower,
          upper: [package, version, upperKind],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension AssetQueryFilter on QueryBuilder<Asset, Asset, QFilterCondition> {
  QueryBuilder<Asset, Asset, QAfterFilterCondition> contentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> contentGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> contentLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> contentBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'content',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> contentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> contentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> contentContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> contentMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'content',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'content', value: ''),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'content', value: ''),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> kindEqualTo(
    AssetKind value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'kind', value: value),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> kindGreaterThan(
    AssetKind value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'kind',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> kindLessThan(
    AssetKind value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'kind',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> kindBetween(
    AssetKind lower,
    AssetKind upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> packageEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'package',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> packageGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'package',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> packageLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'package',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> packageBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'package',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> packageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'package',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> packageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'package',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> packageContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'package',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> packageMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'package',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> packageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'package', value: ''),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> packageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'package', value: ''),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> versionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> versionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> versionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> versionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'version',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> versionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> versionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> versionContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'version',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> versionMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'version',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> versionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'version', value: ''),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> versionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'version', value: ''),
      );
    });
  }
}

extension AssetQueryObject on QueryBuilder<Asset, Asset, QFilterCondition> {}

extension AssetQueryLinks on QueryBuilder<Asset, Asset, QFilterCondition> {}

extension AssetQuerySortBy on QueryBuilder<Asset, Asset, QSortBy> {
  QueryBuilder<Asset, Asset, QAfterSortBy> sortByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> sortByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> sortByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> sortByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> sortByPackage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'package', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> sortByPackageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'package', Sort.desc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension AssetQuerySortThenBy on QueryBuilder<Asset, Asset, QSortThenBy> {
  QueryBuilder<Asset, Asset, QAfterSortBy> thenByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByPackage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'package', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByPackageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'package', Sort.desc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension AssetQueryWhereDistinct on QueryBuilder<Asset, Asset, QDistinct> {
  QueryBuilder<Asset, Asset, QDistinct> distinctByContent({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Asset, Asset, QDistinct> distinctByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind');
    });
  }

  QueryBuilder<Asset, Asset, QDistinct> distinctByPackage({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'package', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Asset, Asset, QDistinct> distinctByVersion({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version', caseSensitive: caseSensitive);
    });
  }
}

extension AssetQueryProperty on QueryBuilder<Asset, Asset, QQueryProperty> {
  QueryBuilder<Asset, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Asset, String, QQueryOperations> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content');
    });
  }

  QueryBuilder<Asset, AssetKind, QQueryOperations> kindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<Asset, String, QQueryOperations> packageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'package');
    });
  }

  QueryBuilder<Asset, String, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
