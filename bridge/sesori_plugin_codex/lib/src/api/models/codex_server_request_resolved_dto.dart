import "package:freezed_annotation/freezed_annotation.dart";

part "codex_server_request_resolved_dto.freezed.dart";
part "codex_server_request_resolved_dto.g.dart";

/// `serverRequest/resolved` params. [requestId] is the JSON-RPC id of the
/// settled server request: a string or an integer, compared exactly.
@Freezed(fromJson: true, toJson: false, copyWith: false, toStringOverride: false)
sealed class CodexServerRequestResolvedDto with _$CodexServerRequestResolvedDto {
  const factory({required String threadId, required Object requestId}) = _CodexServerRequestResolvedDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexServerRequestResolvedDtoFromJson(json);
}
