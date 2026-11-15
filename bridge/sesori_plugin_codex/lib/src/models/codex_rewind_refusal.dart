import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Why Codex can't edit a session at a message, raised before anything in the
/// conversation changes.
enum CodexRewindRefusal({required final String userFacingReason}) {
  /// The app-server has no `thread/revert` (0.139.0 on PATH has none).
  runtimeTooOld(userFacingReason: "Update Codex to edit messages."),

  /// A legacy (non-paginated) thread, which `thread/revert` refuses. Its
  /// rollout also carries no user item ids Sesori can map.
  legacySession(userFacingReason: "Codex can't edit messages in sessions from older Codex versions."),

  /// `thread/revert` refuses ephemeral threads.
  temporarySession(userFacingReason: "Codex can't edit messages in a temporary session."),

  /// The message is not a user item of the thread's current history.
  unknownMessage(userFacingReason: "Codex can't find this message to edit it."),

  /// The message was steered into a turn after its first user item. Codex
  /// reverts whole turns, so editing it would remove more than the message.
  midTurn(userFacingReason: "A message sent while the agent was working can't be edited.");

  PluginBranchPointUnavailableException toException({required Object? cause}) => PluginBranchPointUnavailableException(
    operation: "rewind Codex session",
    userFacingReason: userFacingReason,
    cause: cause,
  );
}
