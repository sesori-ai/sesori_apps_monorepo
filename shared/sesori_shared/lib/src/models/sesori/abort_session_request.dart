import "package:freezed_annotation/freezed_annotation.dart";

part "abort_session_request.freezed.dart";
part "abort_session_request.g.dart";

/// What a stop should do about sub-agents the session is still running.
@JsonEnum()
enum SessionAbortSubAgentPolicy() {
  /// Refuse with [SessionAbortRejection] while sub-agents run, so the client
  /// can ask the user; proceeds as [stop] when none run.
  @JsonValue("confirm")
  confirm,

  /// Interrupt the main agent only; running sub-agents keep going.
  @JsonValue("keep")
  keep,

  /// Interrupt the main agent and every running sub-agent.
  @JsonValue("stop")
  stop,
}

/// Request body for `POST /session/abort`.
///
/// A superset of `SessionIdRequest` so an older app's body still decodes.
@Freezed(fromJson: true, toJson: true)
sealed class AbortSessionRequest with _$AbortSessionRequest {
  const factory({
    required String sessionId,
    // COMPATIBILITY 2026-09-02 (v1.8.3): Apps predating scoped stop omit
    // subAgents and mean today's stop-everything. Make it required once those
    // apps are unsupported.
    @Default(SessionAbortSubAgentPolicy.stop) SessionAbortSubAgentPolicy subAgents,
    // COMPATIBILITY 2026-09-03 (v1.8.4): Released apps omit the atomic-stop
    // handshake and retain their own child fanout. Remove the default once
    // v1.8.3 clients are unsupported.
    @Default(false) bool useAtomicStop,
  }) = _AbortSessionRequest;

  factory fromJson(Map<String, dynamic> json) => _$AbortSessionRequestFromJson(json);
}

/// Successful `POST /session/abort` response.
@Freezed(fromJson: true, toJson: true)
sealed class SessionAbortResponse with _$SessionAbortResponse {
  const factory({
    // COMPATIBILITY 2026-09-03 (v1.8.4): Released bridges return `{}` and do
    // not acknowledge bridge-owned descendant handling. Remove the default
    // once v1.8.3 bridges are unsupported.
    @Default(false) bool subAgentsHandled,
  }) = _SessionAbortResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionAbortResponseFromJson(json);
}

/// Closed class of typed abort refusals.
@JsonEnum()
enum SessionAbortRefusalKind() {
  @JsonValue("notPerformed")
  notPerformed,

  @JsonValue("unknown")
  unknownEnumValue,
}

/// Why the bridge could not safely perform an abort.
@JsonEnum()
enum SessionAbortRefusalReason() {
  @JsonValue("residentWorkCompletionUnknown")
  residentWorkCompletionUnknown,

  @JsonValue("unknown")
  unknownEnumValue,
}

/// Typed 409 body when the bridge performed no abort side effect.
@Freezed(fromJson: true, toJson: true)
sealed class SessionAbortRefusal with _$SessionAbortRefusal {
  const factory({
    @JsonKey(unknownEnumValue: SessionAbortRefusalKind.unknownEnumValue) required SessionAbortRefusalKind kind,
    @JsonKey(unknownEnumValue: SessionAbortRefusalReason.unknownEnumValue) required SessionAbortRefusalReason reason,
  }) = _SessionAbortRefusal;

  factory fromJson(Map<String, dynamic> json) => _$SessionAbortRefusalFromJson(json);
}

/// 409 body for a `confirm` stop the bridge refused because sub-agents run.
@Freezed(fromJson: true, toJson: true)
sealed class SessionAbortRejection with _$SessionAbortRejection {
  const factory({
    required int runningSubAgentCount,

    /// Whether the main agent itself is mid-turn, which decides whether a
    /// "main agent only" stop is worth offering.
    required bool mainAgentRunning,

    /// Whether a `keep` stop (main agent only) is honored while the main agent
    /// runs. Backends whose interrupt also stops sub-agents report false.
    // COMPATIBILITY 2026-09-02 (v1.8.3): bridges before this field only refuse
    // when the backend cannot keep sub-agents; drop the default once no such
    // bridge is in production use.
    @Default(false) bool mainAgentOnlySupported,
  }) = _SessionAbortRejection;

  factory fromJson(Map<String, dynamic> json) => _$SessionAbortRejectionFromJson(json);
}
