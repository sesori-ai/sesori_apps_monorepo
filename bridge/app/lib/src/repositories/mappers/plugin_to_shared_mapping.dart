import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

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

extension SessionAbortSubAgentPolicyMapping on SessionAbortSubAgentPolicy {
  PluginAbortSubAgentPolicy toPlugin() => switch (this) {
    SessionAbortSubAgentPolicy.confirm => PluginAbortSubAgentPolicy.confirm,
    SessionAbortSubAgentPolicy.keep => PluginAbortSubAgentPolicy.keep,
    SessionAbortSubAgentPolicy.stop => PluginAbortSubAgentPolicy.stop,
  };
}

extension PluginAbortRejectionMapping on PluginAbortRejectedSubAgentsRunning {
  SessionAbortRejection toShared() => SessionAbortRejection(
    runningSubAgentCount: runningSubAgentCount,
    mainAgentRunning: mainAgentRunning,
    mainAgentOnlySupported: mainAgentOnlySupported,
  );
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
  MessagePart toShared({required String sessionId}) => switch (this) {
    PluginMessagePartText(:final id, :final messageID, :final text) => MessagePart.text(
      id: id,
      sessionID: sessionId,
      messageID: messageID,
      text: text,
    ),
    PluginMessagePartReasoning(:final id, :final messageID, :final text) => MessagePart.reasoning(
      id: id,
      sessionID: sessionId,
      messageID: messageID,
      text: text,
    ),
    PluginMessagePartTool(:final id, :final messageID, :final tool, :final state) => MessagePart.tool(
      id: id,
      sessionID: sessionId,
      messageID: messageID,
      tool: tool ?? "",
      state: state.toShared(),
    ),
    PluginMessagePartSubtask(
      :final id,
      :final messageID,
      :final prompt,
      :final description,
      :final agent,
      :final taskState,
      :final childSessionID,
    ) =>
      MessagePart.subtask(
        id: id,
        sessionID: sessionId,
        messageID: messageID,
        prompt: prompt,
        description: description,
        agent: agent,
        taskState: taskState?.toShared(),
        // Carried through as the plugin reported it. The live path translates
        // it in `SessionEventMapper`; the history path in `SessionRepository`.
        childSessionID: childSessionID,
      ),
    PluginMessagePartStepStart(:final id, :final messageID) => MessagePart.stepStart(
      id: id,
      sessionID: sessionId,
      messageID: messageID,
    ),
    PluginMessagePartStepFinish(:final id, :final messageID) => MessagePart.stepFinish(
      id: id,
      sessionID: sessionId,
      messageID: messageID,
    ),
    PluginMessagePartFile(:final id, :final messageID, :final attachment) => MessagePart.file(
      id: id,
      sessionID: sessionId,
      messageID: messageID,
      attachment: attachment.toShared(),
    ),
    PluginMessagePartSnapshot(:final id, :final messageID) => MessagePart.snapshot(
      id: id,
      sessionID: sessionId,
      messageID: messageID,
    ),
    PluginMessagePartPatch(:final id, :final messageID) => MessagePart.patch(
      id: id,
      sessionID: sessionId,
      messageID: messageID,
    ),
    PluginMessagePartAgent(:final id, :final messageID, :final agentName) => MessagePart.agent(
      id: id,
      sessionID: sessionId,
      messageID: messageID,
      agentName: agentName,
    ),
    PluginMessagePartRetry(:final id, :final messageID, :final attempt, :final retryError) => MessagePart.retry(
      id: id,
      sessionID: sessionId,
      messageID: messageID,
      attempt: attempt,
      retryError: retryError,
    ),
    PluginMessagePartCompaction(:final id, :final messageID) => MessagePart.compaction(
      id: id,
      sessionID: sessionId,
      messageID: messageID,
    ),
    PluginMessagePartUnknown() => throw StateError(
      "PluginMessagePartUnknown must be filtered out before mapping to shared model",
    ),
  };
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
