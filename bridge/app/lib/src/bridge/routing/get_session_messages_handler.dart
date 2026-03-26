import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

const _idParam = "id";

/// Maps [PluginMessagePartType] to [MessagePartType] with compile-time safety.
/// An exhaustive switch ensures any new enum value causes a compile error here,
/// rather than a runtime crash from `values.byName()`.
MessagePartType _mapPartType(PluginMessagePartType type) => switch (type) {
  PluginMessagePartType.text => MessagePartType.text,
  PluginMessagePartType.reasoning => MessagePartType.reasoning,
  PluginMessagePartType.tool => MessagePartType.tool,
  PluginMessagePartType.subtask => MessagePartType.subtask,
  PluginMessagePartType.stepStart => MessagePartType.stepStart,
  PluginMessagePartType.stepFinish => MessagePartType.stepFinish,
  PluginMessagePartType.file => MessagePartType.file,
  PluginMessagePartType.snapshot => MessagePartType.snapshot,
};

/// Handles `GET /session/:id/message` — returns all messages for a session.
class GetSessionMessagesHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetSessionMessagesHandler(this._plugin) : super(HttpMethod.get, "/session/:$_idParam/message");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final sessionId = pathParams[_idParam];
    if (sessionId == null || sessionId.isEmpty) {
      return buildErrorResponse(request, 400, "missing session id");
    }

    final pluginMessages = await _plugin.getSessionMessages(sessionId);

    final messages = pluginMessages
        .map(
          (m) => MessageWithParts(
            info: Message(
              role: m.info.role,
              id: m.info.id,
              sessionID: m.info.sessionID,
              agent: m.info.agent,
              modelID: m.info.modelID,
              providerID: m.info.providerID,
            ),
            parts: m.parts
                .map(
                  (p) => MessagePart(
                    id: p.id,
                    sessionID: p.sessionID,
                    messageID: p.messageID,
                    type: _mapPartType(p.type),
                    text: p.text,
                    tool: p.tool,
                    state: switch (p.state) {
                      PluginToolState(:final status, :final title, :final output, :final error) => ToolState(
                        status: status,
                        title: title,
                        output: output,
                        error: error,
                      ),
                      null => null,
                    },
                    prompt: p.prompt,
                    description: p.description,
                    agent: p.agent,
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    final body = jsonEncode(messages.map((m) => m.toJson()).toList());
    return buildOkJsonResponse(request, body);
  }
}
