// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_setup_response.dart';

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
      actionHint: json['actionHint'] as String?,
    );

Map<String, dynamic> _$PluginSetupMetadataToJson(
  _PluginSetupMetadata instance,
) => <String, dynamic>{
  'id': instance.id,
  'displayName': instance.displayName,
  'state': _$PluginSetupStateEnumMap[instance.state]!,
  'actionHint': ?instance.actionHint,
};

const _$PluginSetupStateEnumMap = {
  PluginSetupState.notInspected: 'notInspected',
  PluginSetupState.ready: 'ready',
  PluginSetupState.runtimeMissing: 'runtimeMissing',
  PluginSetupState.authenticationRequired: 'authenticationRequired',
  PluginSetupState.unavailable: 'unavailable',
  PluginSetupState.unknown: 'unknown',
};

_PluginSetupResponse _$PluginSetupResponseFromJson(Map json) =>
    _PluginSetupResponse(
      plugins: (json['plugins'] as List<dynamic>)
          .map(
            (e) => PluginSetupMetadata.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

Map<String, dynamic> _$PluginSetupResponseToJson(
  _PluginSetupResponse instance,
) => <String, dynamic>{
  'plugins': instance.plugins.map((e) => e.toJson()).toList(),
};
