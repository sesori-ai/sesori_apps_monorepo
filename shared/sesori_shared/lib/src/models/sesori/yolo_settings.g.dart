// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'yolo_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_YoloSettingsResponse _$YoloSettingsResponseFromJson(Map json) =>
    _YoloSettingsResponse(
      enabled: json['enabled'] as bool,
      supportsSessionOverride:
          json['supportsSessionOverride'] as bool? ?? false,
    );

Map<String, dynamic> _$YoloSettingsResponseToJson(
  _YoloSettingsResponse instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'supportsSessionOverride': instance.supportsSessionOverride,
};
