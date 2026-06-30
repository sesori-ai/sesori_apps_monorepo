// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_project_storage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexOpenedProject _$CodexOpenedProjectFromJson(Map json) =>
    _CodexOpenedProject(
      path: json['path'] as String? ?? "",
      name: json['name'] as String?,
      addedAt: (json['addedAt'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CodexOpenedProjectToJson(_CodexOpenedProject instance) =>
    <String, dynamic>{
      'path': instance.path,
      'name': instance.name,
      'addedAt': instance.addedAt,
    };
