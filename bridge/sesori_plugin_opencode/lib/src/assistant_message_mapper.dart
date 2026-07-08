import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/openapi/assistant_message.g.dart";

/// Maps an OpenCode [AssistantMessage] to a plugin [PluginMessage],
/// normalizing OpenCode's backend-specific error shape.
///
/// OpenCode reports a failed assistant turn as an assistant message that
/// still has `role: "assistant"` but carries a non-null `error`
/// (`{ "name": ..., "data": { "message": ... } }`). Both the REST load path
/// and the live SSE path must collapse that into a flat
/// [PluginMessage.error] so the phone renders it as an error — otherwise the
/// live path silently drops the error and shows a blank assistant turn until
/// the session is re-opened. This mapper is the single owner of that
/// normalization, shared by both paths so they can never diverge again.
class AssistantMessageMapper {
  const AssistantMessageMapper();

  PluginMessage map(AssistantMessage message) {
    final time = PluginMessageTime(
      created: message.time.created,
      completed: message.time.completed,
    );
    final error = message.error;
    final errorMap = error is Map<String, dynamic> ? error : null;
    if (errorMap == null) {
      return PluginMessage.assistant(
        id: message.id,
        sessionID: message.sessionID,
        agent: message.agent,
        modelID: message.modelID,
        providerID: message.providerID,
        time: time,
      );
    }
    final data = errorMap["data"];
    final dataMap = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return PluginMessage.error(
      id: message.id,
      sessionID: message.sessionID,
      agent: message.agent,
      modelID: message.modelID,
      providerID: message.providerID,
      errorName: errorMap["name"]?.toString() ?? "UnknownError",
      errorMessage: dataMap["message"]?.toString() ?? "Unknown error",
      time: time,
    );
  }
}
