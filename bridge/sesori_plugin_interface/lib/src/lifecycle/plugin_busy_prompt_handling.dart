/// What a backend does with a prompt sent while one of its sessions is
/// running a turn.
enum PluginBusyPromptHandling() {
  /// The prompt joins the running turn, which takes it at its next boundary.
  steer,

  /// The running turn is stopped first, and the prompt then starts a new turn.
  stopTurn,
}
