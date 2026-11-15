/// Whether a session's native owner can take new work now.
enum SessionReadiness() {
  idle,
  busy,
  retrying,
  queued,
  awaitingInput,
  unavailable,
  unknown,
}
