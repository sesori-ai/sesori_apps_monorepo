import "package:freezed_annotation/freezed_annotation.dart";

part "claude_mcp_status_dto.freezed.dart";
part "claude_mcp_status_dto.g.dart";

enum ClaudeMcpStatus() {
  unknown,
  pending,
  connected,
  failed,
  disabled,
  @JsonValue("needs-auth")
  needsAuth,
}

enum ClaudeMcpConfigurationScope() { unknown, user, local, project, dynamic, managed }

/// Selective native DTO: never retain launch arguments, environment or headers.
@Freezed(copyWith: false, fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeMcpStatusDto with _$ClaudeMcpStatusDto {
  const factory({required List<ClaudeMcpServerStatusDto> mcpServers}) = _ClaudeMcpStatusDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeMcpStatusDtoFromJson(json);
}

@Freezed(copyWith: false, fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeMcpServerStatusDto with _$ClaudeMcpServerStatusDto {
  const factory({
    required String name,
    @JsonKey(unknownEnumValue: ClaudeMcpStatus.unknown) required ClaudeMcpStatus status,
    @JsonKey(unknownEnumValue: ClaudeMcpConfigurationScope.unknown) required ClaudeMcpConfigurationScope? scope,
    required ClaudeMcpServerInfoDto? serverInfo,
    required ClaudeMcpConfigDto? config,
    required List<ClaudeMcpToolDto>? tools,
  }) = _ClaudeMcpServerStatusDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeMcpServerStatusDtoFromJson(json);
}

@Freezed(copyWith: false, fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeMcpServerInfoDto with _$ClaudeMcpServerInfoDto {
  const factory({required String? title, required String? description}) = _ClaudeMcpServerInfoDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeMcpServerInfoDtoFromJson(json);
}

@Freezed(copyWith: false, fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeMcpConfigDto with _$ClaudeMcpConfigDto {
  const factory({
    required String? url,
  }) = _ClaudeMcpConfigDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeMcpConfigDtoFromJson(json);
}

@Freezed(copyWith: false, fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeMcpToolDto with _$ClaudeMcpToolDto {
  const factory({required String name, required String? description}) = _ClaudeMcpToolDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeMcpToolDtoFromJson(json);
}
