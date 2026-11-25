// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bridge_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BridgeAgentToolGroupSettings _$BridgeAgentToolGroupSettingsFromJson(
  Map json,
) => _BridgeAgentToolGroupSettings(
  disabledIds:
      (json['disabled'] as List<dynamic>?)?.map((e) => e as String).toSet() ??
      const <String>{},
);

Map<String, dynamic> _$BridgeAgentToolGroupSettingsToJson(
  _BridgeAgentToolGroupSettings instance,
) => <String, dynamic>{'disabled': instance.disabledIds.toList()};
