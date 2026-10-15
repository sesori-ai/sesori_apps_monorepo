// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_mcp_status_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexMcpStatusPageDto _$CodexMcpStatusPageDtoFromJson(Map json) =>
    _CodexMcpStatusPageDto(
      data: (json['data'] as List<dynamic>)
          .map(
            (e) => CodexMcpServerStatusDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );

_CodexMcpServerStatusDto _$CodexMcpServerStatusDtoFromJson(Map json) =>
    _CodexMcpServerStatusDto(
      name: json['name'] as String,
      tools: (json['tools'] as Map).map(
        (k, e) => MapEntry(
          k as String,
          CodexMcpToolDto.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      ),
      authStatus:
          $enumDecodeNullable(
            _$CodexMcpAuthStatusEnumMap,
            json['authStatus'],
            unknownValue: CodexMcpAuthStatus.unknown,
          ) ??
          CodexMcpAuthStatus.unknown,
      runtimeStatus: $enumDecodeNullable(
        _$CodexMcpRuntimeStatusEnumMap,
        json['runtimeStatus'],
        unknownValue: CodexMcpRuntimeStatus.unknown,
      ),
      toolsError: json['toolsError'] as String?,
      httpOrigin: json['httpOrigin'] as String?,
      serverInfo: json['serverInfo'] == null
          ? null
          : CodexMcpServerInfoDto.fromJson(
              Map<String, dynamic>.from(json['serverInfo'] as Map),
            ),
    );

const _$CodexMcpAuthStatusEnumMap = {
  CodexMcpAuthStatus.unknown: 'unknown',
  CodexMcpAuthStatus.unsupported: 'unsupported',
  CodexMcpAuthStatus.notLoggedIn: 'notLoggedIn',
  CodexMcpAuthStatus.bearerToken: 'bearerToken',
  CodexMcpAuthStatus.oAuth: 'oAuth',
};

const _$CodexMcpRuntimeStatusEnumMap = {
  CodexMcpRuntimeStatus.unknown: 'unknown',
  CodexMcpRuntimeStatus.notStarted: 'notStarted',
  CodexMcpRuntimeStatus.starting: 'starting',
  CodexMcpRuntimeStatus.connected: 'connected',
  CodexMcpRuntimeStatus.authenticationRequired: 'authenticationRequired',
  CodexMcpRuntimeStatus.failed: 'failed',
  CodexMcpRuntimeStatus.cancelled: 'cancelled',
  CodexMcpRuntimeStatus.disabled: 'disabled',
};

_CodexMcpToolDto _$CodexMcpToolDtoFromJson(Map json) => _CodexMcpToolDto(
  name: json['name'] as String,
  description: json['description'] as String?,
);

_CodexMcpServerInfoDto _$CodexMcpServerInfoDtoFromJson(Map json) =>
    _CodexMcpServerInfoDto(
      title: json['title'] as String?,
      description: json['description'] as String?,
    );
