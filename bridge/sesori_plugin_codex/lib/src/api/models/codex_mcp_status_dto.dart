import "package:freezed_annotation/freezed_annotation.dart";

part "codex_mcp_status_dto.freezed.dart";
part "codex_mcp_status_dto.g.dart";

enum CodexMcpAuthStatus() {
  unknown,
  unsupported,
  notLoggedIn,
  bearerToken,
  oAuth,
}

enum CodexMcpRuntimeStatus() {
  unknown,
  notStarted,
  starting,
  connected,
  authenticationRequired,
  failed,
  cancelled,
  disabled,
}

@Freezed(fromJson: true, toJson: false, copyWith: false, toStringOverride: false)
sealed class CodexMcpStatusPageDto with _$CodexMcpStatusPageDto {
  const factory({required List<CodexMcpServerStatusDto> data, required String? nextCursor}) = _CodexMcpStatusPageDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexMcpStatusPageDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, toStringOverride: false)
sealed class CodexMcpServerStatusDto with _$CodexMcpServerStatusDto {
  const factory({
    required String name,
    required Map<String, CodexMcpToolDto> tools,
    @JsonKey(defaultValue: CodexMcpAuthStatus.unknown, unknownEnumValue: CodexMcpAuthStatus.unknown)
    required CodexMcpAuthStatus authStatus,
    @JsonKey(unknownEnumValue: CodexMcpRuntimeStatus.unknown) required CodexMcpRuntimeStatus? runtimeStatus,
    required String? toolsError,
    required String? httpOrigin,
    required CodexMcpServerInfoDto? serverInfo,
  }) = _CodexMcpServerStatusDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexMcpServerStatusDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, toStringOverride: false)
sealed class CodexMcpToolDto with _$CodexMcpToolDto {
  const factory({required String name, required String? description}) = _CodexMcpToolDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexMcpToolDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, toStringOverride: false)
sealed class CodexMcpServerInfoDto with _$CodexMcpServerInfoDto {
  const factory({required String? title, required String? description}) = _CodexMcpServerInfoDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexMcpServerInfoDtoFromJson(json);
}
