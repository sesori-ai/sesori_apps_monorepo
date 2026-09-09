// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'antigravity_profile_settings_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$AntigravityProfileSettingsDtoToJson(
  _AntigravityProfileSettingsDto instance,
) => <String, dynamic>{'auth': instance.auth.toJson()};

Map<String, dynamic> _$AntigravityProfileAuthDtoToJson(
  _AntigravityProfileAuthDto instance,
) => <String, dynamic>{
  'type': _$AntigravityProfileAuthTypeEnumMap[instance.type]!,
};

const _$AntigravityProfileAuthTypeEnumMap = {
  AntigravityProfileAuthType.personalOauth: 'oauth-personal',
};
