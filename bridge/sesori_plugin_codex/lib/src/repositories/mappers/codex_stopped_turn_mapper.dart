import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// The row ending a turn a user Stop interrupted, live and on replay. [id] is
/// the turn id, as a failed turn's row uses, so the two fold on a reload.
/// Codex records no wording for the stop, so the row carries Sesori's own.
PluginMessage codexStoppedTurnMessage({
  required String id,
  required String sessionId,
  required String? modelId,
  required String? providerId,
  required String? variant,
  required PluginMessageTime? time,
}) => PluginMessage.error(
  id: id,
  sessionID: sessionId,
  agent: "codex",
  modelID: modelId,
  providerID: providerId,
  variant: variant,
  kind: PluginErrorKind.stopped,
  errorName: "CodexTurnAborted",
  errorMessage: "Stopped",
  time: time,
);
