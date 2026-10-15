// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_apps_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexAppsPageDto _$CodexAppsPageDtoFromJson(Map json) => _CodexAppsPageDto(
  data: (json['data'] as List<dynamic>)
      .map((e) => CodexAppInfoDto.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  nextCursor: json['nextCursor'] as String?,
);

_CodexAppInfoDto _$CodexAppInfoDtoFromJson(Map json) => _CodexAppInfoDto(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  isAccessible: json['isAccessible'] as bool? ?? false,
  isEnabled: json['isEnabled'] as bool? ?? true,
);
