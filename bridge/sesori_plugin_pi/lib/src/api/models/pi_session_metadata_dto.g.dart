// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pi_session_metadata_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PiSessionHeaderDto _$PiSessionHeaderDtoFromJson(Map json) => PiSessionHeaderDto(
  version: _intOrNull(json['version']),
  id: _stringOrNull(json['id']),
  timestamp: _timestampOrNull(json['timestamp']),
  cwd: _stringOrNull(json['cwd']),
  parentSession: _stringOrNull(json['parentSession']),
  $type: json['type'] as String?,
);

PiSessionInfoDto _$PiSessionInfoDtoFromJson(Map json) => PiSessionInfoDto(
  name: _strictNullableString(json['name']),
  $type: json['type'] as String?,
);

_PiSettingsDto _$PiSettingsDtoFromJson(Map json) =>
    _PiSettingsDto(sessionDir: _strictNullableString(json['sessionDir']));
