import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Maps [PluginMessagePartType] to [MessagePartType] with compile-time safety.
/// An exhaustive switch ensures any new enum value causes a compile error here,
/// rather than a runtime crash.
extension PluginMessagePartTypeMapping on PluginMessagePartType {
  MessagePartType toShared() => switch (this) {
    PluginMessagePartType.text => MessagePartType.text,
    PluginMessagePartType.reasoning => MessagePartType.reasoning,
    PluginMessagePartType.tool => MessagePartType.tool,
    PluginMessagePartType.subtask => MessagePartType.subtask,
    PluginMessagePartType.stepStart => MessagePartType.stepStart,
    PluginMessagePartType.stepFinish => MessagePartType.stepFinish,
    PluginMessagePartType.file => MessagePartType.file,
    PluginMessagePartType.snapshot => MessagePartType.snapshot,
    PluginMessagePartType.patch => MessagePartType.patch,
    PluginMessagePartType.agent => MessagePartType.agent,
    PluginMessagePartType.retry => MessagePartType.retry,
    PluginMessagePartType.compaction => MessagePartType.compaction,
    PluginMessagePartType.unknown => throw StateError(
      "PluginMessagePartType.unknown must be filtered out before mapping to shared model",
    ),
  };
}

/// Maps [PluginToolStatus] to the shared [ToolStatus] with compile-time
/// exhaustiveness — a new plugin status forces a compile error here rather than
/// silently leaking a wire string. Unlike [PluginMessagePartType], `unknown` is
/// a real renderable state, so it maps through instead of throwing.
extension PluginToolStatusMapping on PluginToolStatus {
  ToolStatus toShared() => switch (this) {
    PluginToolStatus.pending => ToolStatus.pending,
    PluginToolStatus.running => ToolStatus.running,
    PluginToolStatus.completed => ToolStatus.completed,
    PluginToolStatus.error => ToolStatus.error,
    PluginToolStatus.cancelled => ToolStatus.cancelled,
    PluginToolStatus.unknown => ToolStatus.unknown,
  };
}

/// Maps a plugin-normalized attachment into the shared wire contract.
extension PluginMessageAttachmentMapping on PluginMessageAttachment {
  MessageAttachment toShared() => switch (this) {
    PluginMessageAttachmentInlineImage(:final mime, :final base64, :final filename) => MessageAttachment.inlineImage(
      mime: mime,
      base64: base64,
      filename: normalizePluginMessageAttachmentFilename(filename: filename),
    ),
    PluginMessageAttachmentRemoteUrl(:final mime, :final url, :final filename) => _mapRemoteAttachment(
      mime: mime,
      url: url,
      filename: normalizePluginMessageAttachmentFilename(filename: filename),
    ),
    PluginMessageAttachmentMetadata(:final mime, :final filename) => MessageAttachment.metadata(
      mime: mime,
      filename: normalizePluginMessageAttachmentFilename(filename: filename),
    ),
  };

  static MessageAttachment _mapRemoteAttachment({
    required String mime,
    required Uri url,
    required String? filename,
  }) {
    final scheme = url.scheme.toLowerCase();
    if ((scheme != "http" && scheme != "https") || url.host.isEmpty || url.userInfo.isNotEmpty) {
      Log.w("Plugin returned an invalid remote attachment URL; forwarding metadata only");
      return MessageAttachment.metadata(mime: mime, filename: filename);
    }
    return MessageAttachment.remoteUrl(mime: mime, url: url.toString(), filename: filename);
  }
}

/// Maps [PluginToolState] to the shared [ToolState].
extension PluginToolStateMapping on PluginToolState {
  ToolState toShared() => ToolState(
    status: status.toShared(),
    title: title,
    output: output,
    error: error,
    attachments: attachments.map((attachment) => attachment.toShared()).toList(growable: false),
  );
}

/// Maps a plugin-interface [PluginQuestionInfo] to the shared [QuestionInfo]
/// wire model. Layer-neutral so it can be shared by the SSE path
/// ([BridgeEventMapper]) and the repository/REST path ([PluginPendingQuestion]).
extension PluginQuestionInfoMapping on PluginQuestionInfo {
  QuestionInfo toSharedQuestionInfo() => QuestionInfo(
    question: question,
    header: header,
    options: options.map((o) => QuestionOption(label: o.label, description: o.description)).toList(),
    multiple: multiple,
    custom: custom,
  );
}

/// Maps [PluginMessagePart] to the shared [MessagePart].
extension PluginMessagePartMapping on PluginMessagePart {
  MessagePart toShared({required String sessionId}) => MessagePart(
    id: id,
    sessionID: sessionId,
    messageID: messageID,
    type: type.toShared(),
    text: text,
    tool: tool,
    state: state?.toShared(),
    prompt: prompt,
    description: description,
    agent: agent,
    // Carried through as the plugin reported it. The live path translates it
    // in `SessionEventMapper`; the history path in `SessionRepository`.
    childSessionID: childSessionID,
    agentName: agentName,
    attempt: attempt,
    retryError: retryError,
    attachment: attachment?.toShared(),
  );
}

/// Maps plugin-level queued prompts to the shared wire model.
extension PluginQueuedPromptMapping on PluginQueuedPrompt {
  QueuedSessionPrompt toSharedQueuedPrompt() => QueuedSessionPrompt(
    id: id,
    text: text,
    command: command,
    attachmentCount: attachmentCount,
    createdAt: createdAt,
  );
}

extension PluginQueuedPromptsMapping on Iterable<PluginQueuedPrompt> {
  List<QueuedSessionPrompt> toSharedQueuedPrompts() =>
      map((prompt) => prompt.toSharedQueuedPrompt()).toList(growable: false);
}
