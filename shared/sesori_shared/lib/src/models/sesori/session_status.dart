import "package:freezed_annotation/freezed_annotation.dart";

part "session_status.freezed.dart";

part "session_status.g.dart";

/// Response from `GET /session/status`.
@Freezed(fromJson: true, toJson: true)
sealed class SessionStatusResponse with _$SessionStatusResponse {
  const factory({
    // key is session id, value is status
    required Map<String, SessionStatus> statuses,
    // COMPATIBILITY 2026-07-17 (v1.5.1): Bridges before aggregate plugin statuses omit unavailablePluginIds. Remove @Default and require unavailablePluginIds once pre-v1.5.1 bridges are unsupported.
    @Default(<String>[]) List<String> unavailablePluginIds,
  }) = _SessionStatusResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionStatusResponseFromJson(json);
}

@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class SessionStatus with _$SessionStatus {
  @FreezedUnionValue("idle")
  const factory idle() = SessionStatusIdle;

  @FreezedUnionValue("busy")
  const factory busy({
    /// When the bridge saw the session go busy, in epoch ms on the bridge
    /// clock. Null when the bridge is older, or when it did not see the
    /// session go busy from a non-busy state (it was first seen busy, as after
    /// a bridge restart).
    required int? since,
  }) = SessionStatusBusy;

  @FreezedUnionValue("retry")
  const factory retry({
    required int attempt,
    required String message,
    required int next,

    /// When the bridge saw the session go busy, as for [SessionStatus.busy];
    /// a retry keeps the time of the busy run it belongs to.
    required int? since,
  }) = SessionStatusRetry;

  factory fromJson(Map<String, dynamic> json) => _$SessionStatusFromJson(json);
}
