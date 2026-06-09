/// Typed reasons for a failed session-creation attempt, used by
/// [NewSessionState.error] so the UI can perform an exhaustive switch
/// for localized messages. Keeps the transport-level `ApiError` from
/// `sesori_auth` out of the domain state and presentation layers.
enum NewSessionFailedReason {
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
