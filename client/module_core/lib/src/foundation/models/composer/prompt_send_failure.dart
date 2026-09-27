/// How a prompt send failed, as far as this client can tell.
enum PromptSendFailure() {
  /// The bridge answered with a client error, so the prompt did not run and
  /// the user may remove it.
  rejected,

  /// A server error, timeout or lost response. The prompt may already have
  /// been accepted, so only a same-id Retry is safe.
  uncertain,
}
