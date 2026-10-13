// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_mcp_status_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClaudeMcpStatusDto _$ClaudeMcpStatusDtoFromJson(Map json) =>
    _ClaudeMcpStatusDto(
      mcpServers: (json['mcpServers'] as List<dynamic>)
          .map(
            (e) => ClaudeMcpServerStatusDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

_ClaudeMcpServerStatusDto _$ClaudeMcpServerStatusDtoFromJson(Map json) =>
    _ClaudeMcpServerStatusDto(
      name: json['name'] as String,
      status: $enumDecode(
        _$ClaudeMcpStatusEnumMap,
        json['status'],
        unknownValue: ClaudeMcpStatus.unknown,
      ),
      scope: $enumDecodeNullable(
        _$ClaudeMcpConfigurationScopeEnumMap,
        json['scope'],
        unknownValue: ClaudeMcpConfigurationScope.unknown,
      ),
      serverInfo: json['serverInfo'] == null
          ? null
          : ClaudeMcpServerInfoDto.fromJson(
              Map<String, dynamic>.from(json['serverInfo'] as Map),
            ),
      config: json['config'] == null
          ? null
          : ClaudeMcpConfigDto.fromJson(
              Map<String, dynamic>.from(json['config'] as Map),
            ),
      tools: (json['tools'] as List<dynamic>?)
          ?.map(
            (e) =>
                ClaudeMcpToolDto.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );

const _$ClaudeMcpStatusEnumMap = {
  ClaudeMcpStatus.unknown: 'unknown',
  ClaudeMcpStatus.pending: 'pending',
  ClaudeMcpStatus.connected: 'connected',
  ClaudeMcpStatus.failed: 'failed',
  ClaudeMcpStatus.disabled: 'disabled',
  ClaudeMcpStatus.needsAuth: 'needs-auth',
};

const _$ClaudeMcpConfigurationScopeEnumMap = {
  ClaudeMcpConfigurationScope.unknown: 'unknown',
  ClaudeMcpConfigurationScope.user: 'user',
  ClaudeMcpConfigurationScope.local: 'local',
  ClaudeMcpConfigurationScope.project: 'project',
  ClaudeMcpConfigurationScope.dynamic: 'dynamic',
  ClaudeMcpConfigurationScope.managed: 'managed',
};

_ClaudeMcpServerInfoDto _$ClaudeMcpServerInfoDtoFromJson(Map json) =>
    _ClaudeMcpServerInfoDto(
      title: json['title'] as String?,
      description: json['description'] as String?,
    );

_ClaudeMcpConfigDto _$ClaudeMcpConfigDtoFromJson(Map json) =>
    _ClaudeMcpConfigDto(
      type: $enumDecodeNullable(
        _$ClaudeMcpTransportTypeEnumMap,
        json['type'],
        unknownValue: ClaudeMcpTransportType.unknown,
      ),
      url: json['url'] as String?,
    );

const _$ClaudeMcpTransportTypeEnumMap = {
  ClaudeMcpTransportType.unknown: 'unknown',
  ClaudeMcpTransportType.stdio: 'stdio',
  ClaudeMcpTransportType.http: 'http',
  ClaudeMcpTransportType.sse: 'sse',
};

_ClaudeMcpToolDto _$ClaudeMcpToolDtoFromJson(Map json) => _ClaudeMcpToolDto(
  name: json['name'] as String,
  description: json['description'] as String?,
);
