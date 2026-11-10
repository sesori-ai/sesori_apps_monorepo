import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../hermes_turn_failure_copy.dart";

/// Hermes history replay: the standard collector, minus the row Hermes saves
/// to close a failed turn.
///
/// Live, a failed turn shows Hermes's own explanation as an error notice (see
/// `HermesEventMapper`). Hermes never saves that text; it saves a fixed
/// "Your request was not processed…" row instead. Replaying that row as
/// assistant text would put a second message on every reload next to the
/// stored notice, so it is dropped from the built history.
///
/// The row is dropped after collection, not before: it still ends the failed
/// prompt's message there, so the next prompt is not merged into it.
class HermesReplayCollector({
  required final AcpSessionReplayCollector _standardCollector,
}) implements AcpSessionReplayCollector {
  @override
  void consumeNotification({required AcpNotification notification}) =>
      _standardCollector.consumeNotification(notification: notification);

  @override
  List<PluginMessageWithParts> buildWithAssistantSelection({
    required String? modelId,
    required String? providerId,
    required String? variant,
  }) => [
    for (final message in _standardCollector.buildWithAssistantSelection(
      modelId: modelId,
      providerId: providerId,
      variant: variant,
    ))
      if (!_isFailedTurnBoundary(message: message)) message,
  ];

  /// Only a message that holds nothing but the boundary text: one that also
  /// carries a tool, reasoning or other text is kept whole.
  static bool _isFailedTurnBoundary({required PluginMessageWithParts message}) {
    if (message.info is! PluginMessageAssistant || message.parts.length != 1) return false;
    final part = message.parts.single;
    return part is PluginMessagePartText && isHermesFailedTurnBoundary(text: part.text);
  }
}
