// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_setup_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PluginSetupMetadata _$PluginSetupMetadataFromJson(Map json) =>
    _PluginSetupMetadata(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      state: $enumDecode(
        _$PluginSetupStateEnumMap,
        json['state'],
        unknownValue: PluginSetupState.unknown,
      ),
      runtimeVersion: json['runtimeVersion'] as String?,
      actionHint: json['actionHint'] as String?,
    );

Map<String, dynamic> _$PluginSetupMetadataToJson(
  _PluginSetupMetadata instance,
) => <String, dynamic>{
  'id': instance.id,
  'displayName': instance.displayName,
  'state': _$PluginSetupStateEnumMap[instance.state]!,
  'runtimeVersion': ?instance.runtimeVersion,
  'actionHint': ?instance.actionHint,
};

const _$PluginSetupStateEnumMap = {
  PluginSetupState.notInspected: 'notInspected',
  PluginSetupState.ready: 'ready',
  PluginSetupState.runtimeMissing: 'runtimeMissing',
  PluginSetupState.runtimeOutdated: 'runtimeOutdated',
  PluginSetupState.authenticationRequired: 'authenticationRequired',
  PluginSetupState.unavailable: 'unavailable',
  PluginSetupState.unknown: 'unknown',
};
