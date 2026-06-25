/// Typed, transport-agnostic reason for a failed remote request, surfaced by
/// feature failure states (e.g. [ProjectListState.failed], [SessionListState.failed],
/// [SessionDetailState.failed], [NewSessionState.error]) so the UI can perform an
/// exhaustive switch for localized messages.
///
/// Keeps the transport-level `ApiError` from `sesori_auth` out of domain state
/// and the presentation layer. The cubit translates `ApiError → RemoteFailureReason`
/// at its boundary via the `remoteFailureReason` extension; the UI maps the reason
/// to a localized message.
///
/// This single shared type replaces what would otherwise be one identical enum per
/// feature. Introduce a feature-specific enum only when a feature needs a reason the
/// others don't (as `LoginFailedReason` does for its domain-specific cases).
enum RemoteFailureReason {
  /// The request was rejected because the client is not authenticated.
  notAuthenticated,

  /// The server responded with a non-success status code.
  serverRejected,

  /// The HTTP transport failed — no connection or a network-level error.
  networkDown,

  /// The response could not be understood (bad or empty payload).
  badResponse,

  /// Any other, unexpected failure.
  unknown,
}
