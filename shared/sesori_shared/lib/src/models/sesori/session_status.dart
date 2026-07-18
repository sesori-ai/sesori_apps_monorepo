import "package:freezed_annotation/freezed_annotation.dart";

part "session_status.freezed.dart";

part "session_status.g.dart";

/// Response from `GET /session/status`.
@Freezed(fromJson: true, toJson: true)
sealed class SessionStatusResponse with _$SessionStatusResponse {
  const factory SessionStatusResponse({
    // key is session id, value is status
    required Map<String, SessionStatus> statuses,
    // COMPATIBILITY 2026-07-17 (v1.5.1): Bridges before aggregate plugin statuses omit unavailablePluginIds. Remove @Default and require unavailablePluginIds once pre-v1.5.1 bridges are unsupported.
    @Default(<String>[]) List<String> unavailablePluginIds,
  }) = _SessionStatusResponse;

  factory SessionStatusResponse.fromJson(Map<String, dynamic> json) => _$SessionStatusResponseFromJson(json);
}

@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class SessionStatus with _$SessionStatus {
  @FreezedUnionValue("idle")
  const factory SessionStatus.idle() = SessionStatusIdle;

  @FreezedUnionValue("busy")
  const factory SessionStatus.busy() = SessionStatusBusy;

  @FreezedUnionValue("retry")
  const factory SessionStatus.retry({
    required int attempt,
    required String message,
    required int next,
  }) = SessionStatusRetry;

  factory SessionStatus.fromJson(Map<String, dynamic> json) => _$SessionStatusFromJson(json);
}
