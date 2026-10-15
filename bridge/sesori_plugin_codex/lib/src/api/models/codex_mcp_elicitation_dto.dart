import "package:freezed_annotation/freezed_annotation.dart";

part "codex_mcp_elicitation_dto.freezed.dart";
part "codex_mcp_elicitation_dto.g.dart";

enum CodexMcpElicitationMode() {
  form,
  url,
  unknown,
}

/// Native optional fields are validated into a pending variant by the registry.
@Freezed(fromJson: true, toJson: false, copyWith: false, toStringOverride: false)
sealed class CodexMcpElicitationDto with _$CodexMcpElicitationDto {
  const factory({
    required String threadId,
    required String serverName,
    @JsonKey(unknownEnumValue: CodexMcpElicitationMode.unknown) required CodexMcpElicitationMode mode,
    required String? message,
    required Map<String, Object?>? requestedSchema,
    required String? url,
    required String? elicitationId,
  }) = _CodexMcpElicitationDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexMcpElicitationDtoFromJson(json);
}
