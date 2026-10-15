// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_code_mcp_authentication_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OpenCodeMcpConfigurationDto _$OpenCodeMcpConfigurationDtoFromJson(Map json) =>
    _OpenCodeMcpConfigurationDto(
      mcp:
          (json['mcp'] as Map?)?.map(
            (k, e) => MapEntry(
              k as String,
              OpenCodeMcpServerConfigurationDto.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            ),
          ) ??
          const {},
    );

_OpenCodeMcpServerConfigurationDto _$OpenCodeMcpServerConfigurationDtoFromJson(
  Map json,
) => _OpenCodeMcpServerConfigurationDto(
  transport: $enumDecodeNullable(
    _$OpenCodeMcpTransportEnumMap,
    json['type'],
    unknownValue: OpenCodeMcpTransport.unknown,
  ),
  url: json['url'] as String?,
  oauthEnabled: _oauthEnabled(json['oauth']),
);

const _$OpenCodeMcpTransportEnumMap = {
  OpenCodeMcpTransport.local: 'local',
  OpenCodeMcpTransport.remote: 'remote',
  OpenCodeMcpTransport.unknown: 'unknown',
};

_OpenCodeMcpAuthenticationResponseDto
_$OpenCodeMcpAuthenticationResponseDtoFromJson(Map json) =>
    _OpenCodeMcpAuthenticationResponseDto(
      authorizationUrl: json['authorizationUrl'] as String,
      oauthState: json['oauthState'] as String,
    );
