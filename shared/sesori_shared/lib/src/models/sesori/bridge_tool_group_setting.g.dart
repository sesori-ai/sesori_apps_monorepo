// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bridge_tool_group_setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BridgeToolGroupSetting _$BridgeToolGroupSettingFromJson(Map json) =>
    _BridgeToolGroupSetting(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      enabled: json['enabled'] as bool,
    );

Map<String, dynamic> _$BridgeToolGroupSettingToJson(
  _BridgeToolGroupSetting instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'summary': instance.summary,
  'enabled': instance.enabled,
};
