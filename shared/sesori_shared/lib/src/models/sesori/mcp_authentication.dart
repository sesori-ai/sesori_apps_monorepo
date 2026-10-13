import "package:freezed_annotation/freezed_annotation.dart";

import "mcp.dart";

part "mcp_authentication.freezed.dart";
part "mcp_authentication.g.dart";

/// Whether the native attempt can stop before its authoritative settlement.
enum McpAuthenticationCancellation() {
  unknown,
  cancelable,
  nativeSettlement,
}

@Freezed(copyWith: false, equal: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class McpAuthenticationAttempt with _$McpAuthenticationAttempt {
  const factory({
    required String attemptId,
    required String pluginId,
    @JsonKey(fromJson: McpEntryTarget.serverFromJson) required McpServerTarget target,
    @JsonKey(unknownEnumValue: McpAuthenticationCancellation.unknown)
    required McpAuthenticationCancellation cancellation,
  }) = _McpAuthenticationAttempt;

  factory fromJson(Map<String, dynamic> json) => _$McpAuthenticationAttemptFromJson(json);
}

enum McpAuthenticationFailureReason() {
  unknown,
  nativeFailure,
  declined,
  expired,
  nativeTrustRequired,
  interrupted,
}

/// Current bridge-owned state. Challenges are request-scoped, never SSE payloads.
@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  copyWith: false,
  equal: false,
  fromJson: true,
  toJson: true,
  toStringOverride: false,
)
sealed class McpAuthenticationState with _$McpAuthenticationState {
  const factory unknown() = McpAuthenticationUnknown;
  const factory idle() = McpAuthenticationIdle;
  const factory starting({required McpAuthenticationAttempt attempt}) = McpAuthenticationStarting;
  const factory callbackChallenge({
    required McpAuthenticationAttempt attempt,
    required String authorizationUrl,
    required String expectedCallbackUrl,
  }) = McpAuthenticationCallbackChallenge;

  /// A callback was submitted or cancellation requested; native truth is pending.
  const factory settling({required McpAuthenticationAttempt attempt}) = McpAuthenticationSettling;
  const factory completed({required McpAuthenticationAttempt attempt}) = McpAuthenticationCompleted;
  const factory failed({
    required McpAuthenticationAttempt attempt,
    @JsonKey(unknownEnumValue: McpAuthenticationFailureReason.unknown) required McpAuthenticationFailureReason reason,
  }) = McpAuthenticationFailed;
  const factory cancelled({required McpAuthenticationAttempt attempt}) = McpAuthenticationCancelled;

  factory fromJson(Map<String, dynamic> json) => _$McpAuthenticationStateFromJson(json);
}

@Freezed(copyWith: false, equal: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class McpAuthenticationStartRequest with _$McpAuthenticationStartRequest {
  const factory({
    required String pluginId,
    @JsonKey(fromJson: McpEntryTarget.serverFromJson) required McpServerTarget target,
  }) = _McpAuthenticationStartRequest;

  factory fromJson(Map<String, dynamic> json) => _$McpAuthenticationStartRequestFromJson(json);
}

@Freezed(copyWith: false, equal: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class McpAuthenticationContinueRequest with _$McpAuthenticationContinueRequest {
  const factory({required String attemptId, required String callbackUrl}) = _McpAuthenticationContinueRequest;

  factory fromJson(Map<String, dynamic> json) {
    try {
      return _$McpAuthenticationContinueRequestFromJson(json);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(McpAuthenticationCallbackDecodingException(innerError: error), stackTrace);
    }
  }
}

/// Invalid callback bodies retain their cause without reflecting secret input.
final class const McpAuthenticationCallbackDecodingException({required final Object innerError}) implements Exception {
  @override
  String toString() => "Invalid MCP authentication callback request";
}

@Freezed(copyWith: false, equal: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class McpAuthenticationCancelRequest with _$McpAuthenticationCancelRequest {
  const factory({required String attemptId}) = _McpAuthenticationCancelRequest;

  factory fromJson(Map<String, dynamic> json) => _$McpAuthenticationCancelRequestFromJson(json);
}

enum McpAuthenticationUnavailableReason() {
  unknown,
  unsupportedHarness,
  unsupportedScope,
  liveSessionRequired,
  pluginInactive,
  targetNotFound,
  nativeConfigurationRequired,
  notSupported,
  notImplemented,
  attemptNotFound,
  callbackRejected,
  nativeCancellationUnavailable,
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  copyWith: false,
  equal: false,
  fromJson: true,
  toJson: true,
  toStringOverride: false,
)
sealed class McpAuthenticationResult with _$McpAuthenticationResult {
  const factory unknown() = McpAuthenticationResultUnknown;
  const factory state({required McpAuthenticationState state}) = McpAuthenticationStateResult;

  /// A second start leaves the current native operation and challenge untouched.
  const factory busy() = McpAuthenticationBusy;
  const factory unavailable({
    @JsonKey(unknownEnumValue: McpAuthenticationUnavailableReason.unknown)
    required McpAuthenticationUnavailableReason reason,
  }) = McpAuthenticationUnavailable;

  factory fromJson(Map<String, dynamic> json) => _$McpAuthenticationResultFromJson(json);
}
