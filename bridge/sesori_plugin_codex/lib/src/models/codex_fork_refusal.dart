import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Why Codex can't fork a session through a message, raised before a fork is
/// created.
enum CodexForkRefusal({required final String userFacingReason}) {
  /// The app-server has no `thread/fork {lastTurnId}`. Codex before 0.143.0
  /// drops the unknown field and would fork the whole thread.
  runtimeTooOld(userFacingReason: "Update Codex to fork sessions."),

  /// Codex has no rollout for the session any more.
  missingSession(userFacingReason: "Codex no longer has this session."),

  /// The message is not part of a turn of the thread's current history.
  unknownMessage(userFacingReason: "Codex can't find this message to fork from it."),

  /// A message sent while the agent was working continued the native turn
  /// after the fork point. Codex forks whole turns, so the fork would keep
  /// more than the conversation up to the message.
  midTurn(userFacingReason: "Codex can only fork at the end of a turn, and this turn went on after a later message."),

  /// The turn is still running; Codex forks only finished turns.
  turnRunning(userFacingReason: "Codex can't fork from a turn that is still running.");

  PluginBranchPointUnavailableException toException({required Object? cause}) => PluginBranchPointUnavailableException(
    operation: "fork Codex session",
    userFacingReason: userFacingReason,
    cause: cause,
  );
}
