// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'antigravity_initialize_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AntigravityInitializeDto _$AntigravityInitializeDtoFromJson(Map json) =>
    _AntigravityInitializeDto(
      protocolVersion: (json['protocolVersion'] as num?)?.toInt(),
      agentInfo: json['agentInfo'] == null
          ? null
          : AntigravityAgentInfoDto.fromJson(
              Map<String, dynamic>.from(json['agentInfo'] as Map),
            ),
      agentCapabilities: json['agentCapabilities'] == null
          ? null
          : AntigravityAgentCapabilitiesDto.fromJson(
              Map<String, dynamic>.from(json['agentCapabilities'] as Map),
            ),
      authMethods: (json['authMethods'] as List<dynamic>?)
          ?.map(
            (e) => AntigravityAuthMethodDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

_AntigravityAgentInfoDto _$AntigravityAgentInfoDtoFromJson(Map json) =>
    _AntigravityAgentInfoDto(
      name: json['name'] as String?,
      title: json['title'] as String?,
      version: json['version'] as String?,
    );

_AntigravityAgentCapabilitiesDto _$AntigravityAgentCapabilitiesDtoFromJson(
  Map json,
) => _AntigravityAgentCapabilitiesDto(
  loadSession: json['loadSession'] as bool?,
  sessionCapabilities: json['sessionCapabilities'] == null
      ? null
      : AntigravitySessionCapabilitiesDto.fromJson(
          Map<String, dynamic>.from(json['sessionCapabilities'] as Map),
        ),
  auth: json['auth'] == null
      ? null
      : AntigravityAuthCapabilitiesDto.fromJson(
          Map<String, dynamic>.from(json['auth'] as Map),
        ),
);

_AntigravitySessionCapabilitiesDto _$AntigravitySessionCapabilitiesDtoFromJson(
  Map json,
) => _AntigravitySessionCapabilitiesDto(
  list: const AntigravityCapabilityPresenceConverter().fromJson(json['list']),
  resume: const AntigravityCapabilityPresenceConverter().fromJson(
    json['resume'],
  ),
  close: const AntigravityCapabilityPresenceConverter().fromJson(json['close']),
);

_AntigravityAuthCapabilitiesDto _$AntigravityAuthCapabilitiesDtoFromJson(
  Map json,
) => _AntigravityAuthCapabilitiesDto(
  logout: const AntigravityCapabilityPresenceConverter().fromJson(
    json['logout'],
  ),
);

_AntigravityAuthMethodDto _$AntigravityAuthMethodDtoFromJson(Map json) =>
    _AntigravityAuthMethodDto(id: json['id'] as String?);
