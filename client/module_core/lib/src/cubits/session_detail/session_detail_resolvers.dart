import "package:sesori_shared/sesori_shared.dart";

import "session_detail_state.dart";

extension SessionMessagePresentation on MessageWithParts {
  bool get hasRenderableUserContent {
    if (info is! MessageUser) return true;
    return parts.any(
      (part) => switch (part) {
        MessagePartText(:final text) => text.isNotEmpty,
        MessagePartFile(:final attachment) => attachment is! MessageAttachmentUnknown,
        MessagePartReasoning() ||
        MessagePartTool() ||
        MessagePartSubtask() ||
        MessagePartStepStart() ||
        MessagePartStepFinish() ||
        MessagePartSnapshot() ||
        MessagePartPatch() ||
        MessagePartAgent() ||
        MessagePartRetry() ||
        MessagePartCompaction() => false,
      },
    );
  }

  /// What a user prompt says, wherever the app names it outside its bubble:
  /// its whole text, else its first attachment's name, else null. Views show
  /// their localized "Attachment" for null.
  String? get promptText {
    final text = parts.whereType<MessagePartText>().map((part) => part.text).join("\n");
    if (text.isNotEmpty) return text;
    final filename = switch (parts.whereType<MessagePartFile>().firstOrNull?.attachment) {
      MessageAttachmentInlineImage(:final filename) ||
      MessageAttachmentRemoteUrl(:final filename) ||
      MessageAttachmentStoredImage(:final filename) ||
      MessageAttachmentMetadata(:final filename) => filename?.trim(),
      MessageAttachmentUnknown() || null => null,
    };
    return filename == null || filename.isEmpty ? null : filename;
  }
}

/// The first line of [text] that holds more than whitespace, trimmed; null
/// when none does. Stops at that line, since the text can be long.
String? firstNonBlankLine({required String text}) {
  var start = 0;
  while (start < text.length) {
    final newline = text.indexOf("\n", start);
    final end = newline < 0 ? text.length : newline;
    final line = text.substring(start, end).trim();
    if (line.isNotEmpty) return line;
    start = end + 1;
  }
  return null;
}

extension SessionTranscriptReplies on List<MessageWithParts> {
  /// What the newest agent-authored assistant or error message ran with, or
  /// null when there is none. Automation replies and user turns are skipped.
  ({String? agent, String? providerID, String? modelID})? get latestAgentReply {
    for (final message in reversed) {
      switch (message.info) {
        case MessageAssistant(sender: MessageSender.agent, :final agent, :final providerID, :final modelID) ||
            MessageError(:final agent, :final providerID, :final modelID):
          return (agent: agent, providerID: providerID, modelID: modelID);
        case MessageAssistant() || MessageUser():
          continue;
      }
    }
    return null;
  }
}

extension SessionDetailRunResolvers on SessionDetailLoaded {
  /// The agent and model this session ran with, for surfaces that show rather
  /// than choose them: the bridge's prompt defaults, else the newest agent
  /// reply. Unlike the composer's selection nothing falls back to a catalog
  /// default, so an unknown part stays null. A reply records no variant.
  ({String? agent, AgentModel? model}) get ranWith {
    final reply = messages.latestAgentReply;
    final providerID = reply?.providerID;
    final modelID = reply?.modelID;
    return (
      agent: promptDefaults?.agent ?? reply?.agent,
      model:
          promptDefaults?.model ??
          (providerID == null || modelID == null
              ? null
              : AgentModel(providerID: providerID, modelID: modelID, variant: null)),
    );
  }
}

/// Whether a sub-agent with [status] works now: busy or retrying. The one rule
/// for a running sub-agent, shared by the composer pill, the session's active
/// work and the transcript's sub-agent row.
bool isChildRunning({required SessionStatus? status}) => status is SessionStatusBusy || status is SessionStatusRetry;

/// The sub-agents among [children] that work now, by [isChildRunning].
List<Session> runningChildren({
  required List<Session> children,
  required Map<String, SessionStatus> childStatuses,
}) => [
  for (final child in children)
    if (isChildRunning(status: childStatuses[child.id])) child,
];

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
        if (p.id != partId) continue;
        final text = switch (p) {
          MessagePartText(:final text) || MessagePartReasoning(:final text) => text,
          MessagePartTool() ||
          MessagePartSubtask() ||
          MessagePartStepStart() ||
          MessagePartStepFinish() ||
          MessagePartFile() ||
          MessagePartSnapshot() ||
          MessagePartPatch() ||
          MessagePartAgent() ||
          MessagePartRetry() ||
          MessagePartCompaction() => null,
        };
        return (text: text ?? "", isStreaming: false);
      }
    }

    return (text: "", isStreaming: false);
  }
}
