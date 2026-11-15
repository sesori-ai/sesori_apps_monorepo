/// Message-level branching operations a started plugin implements.
///
/// Declared on the descriptor so clients learn which harnesses can edit or
/// fork a session without starting them.
enum PluginSessionBranching() {
  /// The plugin implements `SessionRewindPluginApi`: it can remove a turn and
  /// everything after it from a session's conversation and send an edited
  /// prompt in its place.
  rewind,

  /// The plugin can fork a session from a message into a new session in the
  /// same directory.
  fork,
}
