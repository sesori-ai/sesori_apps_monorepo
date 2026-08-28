// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_options_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionOptionsResponse _$SessionOptionsResponseFromJson(Map json) =>
    _SessionOptionsResponse(
      agents: Agents.fromJson(Map<String, dynamic>.from(json['agents'] as Map)),
      providers: ProviderListResponse.fromJson(
        Map<String, dynamic>.from(json['providers'] as Map),
      ),
      commands: CommandListResponse.fromJson(
        Map<String, dynamic>.from(json['commands'] as Map),
      ),
      lastUsedPromptDefaults: json['lastUsedPromptDefaults'] == null
          ? null
          : SessionPromptDefaults.fromJson(
              Map<String, dynamic>.from(json['lastUsedPromptDefaults'] as Map),
            ),
      stale: json['stale'] as bool? ?? false,
    );

Map<String, dynamic> _$SessionOptionsResponseToJson(
  _SessionOptionsResponse instance,
) => <String, dynamic>{
  'agents': instance.agents.toJson(),
  'providers': instance.providers.toJson(),
  'commands': instance.commands.toJson(),
  'lastUsedPromptDefaults': ?instance.lastUsedPromptDefaults?.toJson(),
  'stale': instance.stale,
};
