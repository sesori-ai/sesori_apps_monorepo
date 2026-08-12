import "package:sesori_shared/sesori_shared.dart";

import "session_detail_state.dart";

extension SessionMessagePresentation on MessageWithParts {
  bool get hasRenderableUserContent {
    if (info is! MessageUser) return true;
    return parts.any(
      (part) =>
          (part.type == MessagePartType.text && (part.text?.isNotEmpty ?? false)) ||
          (part.type == MessagePartType.file && part.attachment != null),
    );
  }
}

/// Pure-data resolvers for [SessionDetailState].
///
/// Keeps data-derivation logic in module_core rather than in
/// presentation widgets, satisfying the layered architecture.
extension SessionDetailResolvers on SessionDetailState {
  bool get hasRenderableMessages {
    final self = this;
    return self is SessionDetailLoaded && self.messages.any((message) => message.hasRenderableUserContent);
  }

  /// Resolves the display text and streaming flag for a reasoning part.
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
}
