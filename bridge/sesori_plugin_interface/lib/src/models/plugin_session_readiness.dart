/// Evidence from a session's native owner about whether it can take new work
/// now, including native retries, queued input and input waits.
enum PluginSessionReadiness() {
  idle,
  busy,
  retrying,
  queued,
  awaitingInput,
  unavailable,
  unknown,
}
