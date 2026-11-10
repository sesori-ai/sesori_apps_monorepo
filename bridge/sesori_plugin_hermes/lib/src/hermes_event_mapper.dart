import "package:acp_plugin/acp_plugin.dart";

import "hermes_turn_failure_copy.dart";

/// Hermes's event mapper: the standard ACP mapping from [AcpEventMapper], plus
/// Hermes's notice for a turn its model provider never answered.
///
/// Hermes reports that failure as its ordinary final response and ends the
/// turn with `stopReason: end_turn`, so on the wire the notice looks like a
/// reply. It is recognized by its text and shown as an error notice.
class HermesEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
}) extends AcpEventMapper {
  /// Drops the message id from a provider-failure chunk.
  ///
  /// The shared mapper reads only id-less chunks as halt notices, because an
  /// identified message may still grow. Hermes sends this notice as its whole,
  /// unstreamed final response under a fresh message id and closes that id
  /// straight away (`acp_adapter/server.py::_finish_turn`), so nothing can
  /// join it and the id carries no grouping.
  @override
  Map<String, dynamic> normalizeSessionUpdate({required Map<String, dynamic> params}) {
    final update = params["update"];
    if (update is! Map || update["sessionUpdate"] != "agent_message_chunk" || !update.containsKey("messageId")) {
      return params;
    }
    final content = update["content"];
    if (content is! Map || content["type"] != "text") return params;
    final text = content["text"];
    if (text is! String || !isHermesProviderFailureNotice(text: text)) return params;
    return {
      ...params,
      "update": Map<String, dynamic>.of(update.cast<String, dynamic>())..remove("messageId"),
    };
  }

  @override
  AcpHaltNotice? classifyHaltNotice({required String text}) {
    if (!isHermesProviderFailureNotice(text: text)) return null;
    // The shared mapper keeps Hermes's exact wording as the shown message.
    return const AcpHaltNotice(errorName: "hermes_provider_failure");
  }
}
