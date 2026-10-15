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
  oauth: _oauthConfiguration(json['oauth']),
);

const _$OpenCodeMcpTransportEnumMap = {
  OpenCodeMcpTransport.local: 'local',
  OpenCodeMcpTransport.remote: 'remote',
  OpenCodeMcpTransport.unknown: 'unknown',
};

_OpenCodeMcpOAuthParametersDto _$OpenCodeMcpOAuthParametersDtoFromJson(
  Map json,
) =>
    _OpenCodeMcpOAuthParametersDto(redirectUri: json['redirectUri'] as String?);

_OpenCodeMcpAuthenticationResponseDto
_$OpenCodeMcpAuthenticationResponseDtoFromJson(Map json) =>
    _OpenCodeMcpAuthenticationResponseDto(
      authorizationUrl: json['authorizationUrl'] as String,
      oauthState: json['oauthState'] as String,
    );
