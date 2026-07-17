import "package:sesori_shared/sesori_shared.dart";

import "session_detail_state.dart";

/// Pure-data resolvers for [SessionDetailState].
///
/// Keeps data-derivation logic in module_core rather than in
/// presentation widgets, satisfying the layered architecture.
extension SessionDetailResolvers on SessionDetailState {
  /// Resolves the display text and streaming flag for a message part.
  ///
  /// Returns the streaming text if the part is actively streaming,
  /// otherwise falls back to the finalized text in [messages].
  ({String text, bool isStreaming}) resolvePartContent({
    required String partId,
    required String messageId,
  }) {
    final self = this;
    if (self is! SessionDetailLoaded) return (text: "", isStreaming: false);

    final streaming = self.streamingText[partId];
    if (streaming != null) return (text: streaming, isStreaming: true);

    for (final m in self.messages) {
      if (m.info.id != messageId) continue;
      for (final p in m.parts) {
        if (p.id == partId) return (text: p.text ?? "", isStreaming: false);
      }
    }

    return (text: "", isStreaming: false);
  }

  /// Resolves the result selected by [command] for a command message.
  ///
  /// A streaming value takes precedence over the finalized message part. The
  /// text is null only when the command's selected part does not exist in the
  /// current state.
  String? resolveCommandResultText({
    required CommandMessageInfo command,
    required String messageId,
  }) {
    final content = resolvePartContent(
      partId: command.displayPartID,
      messageId: messageId,
    );
    if (content.isStreaming) {
      return content.text;
    }

    final self = this;
    if (self is! SessionDetailLoaded) {
      return null;
    }
    for (final message in self.messages) {
      if (message.info.id != messageId) continue;
      for (final part in message.parts) {
        if (part.id == command.displayPartID) {
          return content.text;
        }
      }
    }

    return null;
  }
}
