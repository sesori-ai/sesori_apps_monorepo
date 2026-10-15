import "package:freezed_annotation/freezed_annotation.dart";

part "codex_mcp_oauth_dto.freezed.dart";
part "codex_mcp_oauth_dto.g.dart";

@Freezed(fromJson: true, toJson: false, copyWith: false, toStringOverride: false)
sealed class CodexMcpOAuthLoginDto with _$CodexMcpOAuthLoginDto {
  const factory({required String authorizationUrl}) = _CodexMcpOAuthLoginDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexMcpOAuthLoginDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, toStringOverride: false)
sealed class CodexMcpOAuthCompletionDto with _$CodexMcpOAuthCompletionDto {
  const factory({required String name, required bool success, required String? error, required String? threadId}) =
      _CodexMcpOAuthCompletionDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexMcpOAuthCompletionDtoFromJson(json);
}

enum CodexMcpOAuthFailureKind() {
  nativeFailure,
  expired,
  declined,
}

extension CodexMcpOAuthFailureParsing on CodexMcpOAuthCompletionDto {
  // Exact native failures verified at both supported pins; unknown text stays a
  // generic native failure rather than guessing from arbitrary provider text.
  CodexMcpOAuthFailureKind get failureKind => switch (error) {
    "timed out waiting for OAuth callback" => CodexMcpOAuthFailureKind.expired,
    "OAuth provider returned `access_denied`" => CodexMcpOAuthFailureKind.declined,
    _ => CodexMcpOAuthFailureKind.nativeFailure,
  };
}
