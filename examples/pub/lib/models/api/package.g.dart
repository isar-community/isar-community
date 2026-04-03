// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'package.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiPackage _$ApiPackageFromJson(Map<String, dynamic> json) => ApiPackage(
      name: json['name'] as String,
      latest:
          ApiPackageVersion.fromJson(json['latest'] as Map<String, dynamic>),
      versions: (json['versions'] as List<dynamic>?)
              ?.map(
                  (e) => ApiPackageVersion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

ApiPackageVersion _$ApiPackageVersionFromJson(Map<String, dynamic> json) =>
    ApiPackageVersion(
      version: json['version'] as String,
      pubspec: PubSpec.fromJson(json['pubspec'] as Map<String, dynamic>?),
      published: DateTime.parse(json['published'] as String),
    );
