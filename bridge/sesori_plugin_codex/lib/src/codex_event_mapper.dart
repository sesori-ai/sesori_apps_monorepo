import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "repositories/models/codex_app_server_repository_models.dart";
import "trackers/codex_context_tracker.dart";

/// Pure translation from typed Codex records into bridge-neutral events.
class CodexEventMapper {
  const CodexEventMapper();

  List<BridgeSseEvent> map(
    CodexEventRecord event, {
    required CodexEventContext context,
  }) {
    switch (event) {
      case CodexThreadStartedEventRecord(:final thread):
        if (thread == null) return const [];
        return [
          BridgeSseSessionCreated(
            info: _threadToSession(thread, context).toJson(),
          ),
        ];
      case CodexThreadNameUpdatedEventRecord(:final threadName):
        final threadId = event.threadId;
        if (threadId == null) return const [];
        return [
          BridgeSseSessionUpdated(
            info: _minimalSession(
              id: threadId,
              title: threadName,
              context: context,
            ).toJson(),
            titleChanged: true,
          ),
        ];
      case CodexThreadStatusChangedEventRecord(:final status):
        final threadId = event.threadId;
        if (threadId == null) return const [];
        return [
          BridgeSseSessionStatus(
            sessionID: threadId,
            status: switch (status) {
              CodexThreadStatus.idle => const shared.SessionStatus.idle().toJson(),
              CodexThreadStatus.busy => const shared.SessionStatus.busy().toJson(),
            },
          ),
        ];
      case CodexTurnStartedEventRecord():
        final threadId = event.threadId;
        if (threadId == null) return const [];
        return [
          BridgeSseSessionStatus(
            sessionID: threadId,
            status: const shared.SessionStatus.busy().toJson(),
          ),
        ];
      case CodexTurnCompletedEventRecord():
        final threadId = event.threadId;
        if (threadId == null) return const [];
        return [BridgeSseSessionIdle(sessionID: threadId)];
      case CodexItemEventRecord(:final item):
        final threadId = event.threadId;
        if (item == null || threadId == null) return const [];
        return _itemToEvents(
          item: item,
          threadId: threadId,
          context: context,
        );
      case CodexAgentMessageDeltaEventRecord(:final itemId, :final delta):
        return _deltaEvent(
          threadId: event.threadId,
          itemId: itemId,
          delta: delta,
          partSuffix: "text",
        );
      case CodexReasoningDeltaEventRecord(:final itemId, :final delta):
        return _deltaEvent(
          threadId: event.threadId,
          itemId: itemId,
          delta: delta,
          partSuffix: "reasoning",
        );
      case CodexItemRemovedEventRecord(:final itemId):
        final threadId = event.threadId;
        if (threadId == null || itemId == null) return const [];
        return [
          BridgeSseMessageRemoved(
            sessionID: threadId,
            messageID: itemId,
          ),
        ];
      case CodexItemPartRemovedEventRecord(:final itemId, :final partId):
        final threadId = event.threadId;
        if (threadId == null || itemId == null || partId == null) {
          return const [];
        }
        return [
          BridgeSseMessagePartRemoved(
            sessionID: threadId,
            messageID: itemId,
            partID: partId,
          ),
        ];
      case CodexErrorEventRecord():
        return [BridgeSseSessionError(sessionID: event.threadId)];
      case CodexTurnDiffUpdatedEventRecord():
        final threadId = event.threadId;
        if (threadId == null) return const [];
        return [BridgeSseSessionDiff(sessionID: threadId)];
      case CodexProjectChangedEventRecord():
        return const [BridgeSseProjectUpdated()];
      case CodexThreadClosedEventRecord():
      case CodexIgnoredEventRecord():
        return const [];
    }
  }

  List<BridgeSseEvent> _deltaEvent({
    required String? threadId,
    required String? itemId,
    required String? delta,
    required String partSuffix,
  }) {
    if (threadId == null || itemId == null || delta == null) return const [];
    return [
      BridgeSseMessagePartDelta(
        sessionID: threadId,
        messageID: itemId,
        partID: "$itemId-$partSuffix",
        field: "text",
        delta: delta,
      ),
    ];
  }

  List<BridgeSseEvent> _itemToEvents({
    required CodexItemRecord item,
    required String threadId,
    required CodexEventContext context,
  }) {
    return switch (item) {
      CodexUserMessageItemRecord(:final id, :final text) => _messageEvents(
        threadId: threadId,
        itemId: id,
        message: shared.Message.user(
          id: id,
          sessionID: threadId,
          agent: null,
          time: null,
        ),
        partType: PluginMessagePartType.text,
        partSuffix: "text",
        text: text,
      ),
      CodexAgentMessageItemRecord(:final id, :final text) => _messageEvents(
        threadId: threadId,
        itemId: id,
        message: _assistantMessage(
          itemId: id,
          threadId: threadId,
          context: context,
        ),
        partType: PluginMessagePartType.text,
        partSuffix: "text",
        text: text,
      ),
      CodexReasoningItemRecord(:final id, :final text) => _messageEvents(
        threadId: threadId,
        itemId: id,
        message: _assistantMessage(
          itemId: id,
          threadId: threadId,
          context: context,
        ),
        partType: PluginMessagePartType.reasoning,
        partSuffix: "reasoning",
        text: text,
      ),
      CodexToolItemRecord(
        :final id,
        :final tool,
        :final title,
        :final status,
        :final output,
        :final error,
      ) =>
        _toolItemEvents(
          threadId: threadId,
          itemId: id,
          tool: tool,
          title: title,
          status: switch (status) {
            CodexToolStatus.running => PluginToolStatus.running,
            CodexToolStatus.completed => PluginToolStatus.completed,
            CodexToolStatus.error => PluginToolStatus.error,
          },
          output: output,
          error: error,
          context: context,
        ),
      CodexUnsupportedItemRecord() => const [],
    };
  }

  List<BridgeSseEvent> _toolItemEvents({
    required String threadId,
    required String itemId,
    required String tool,
    required PluginToolStatus status,
    required CodexEventContext context,
    required String? title,
    required String? output,
    required String? error,
  }) {
    return [
      BridgeSseMessageUpdated(
        info: _assistantMessage(
          itemId: itemId,
          threadId: threadId,
          context: context,
        ).toJson(),
      ),
      BridgeSseMessagePartUpdated(
        part: PluginMessagePart(
          id: "$itemId-tool",
          sessionID: threadId,
          messageID: itemId,
          type: PluginMessagePartType.tool,
          text: "",
          tool: tool,
          state: PluginToolState(
            status: status,
            title: title,
            output: output,
            error: error ?? (status == PluginToolStatus.error ? output : null),
          ),
          prompt: null,
          description: null,
          agent: null,
          agentName: null,
          attempt: null,
          retryError: null,
        ),
      ),
    ];
  }

  shared.Message _assistantMessage({
    required String itemId,
    required String threadId,
    required CodexEventContext context,
  }) {
    return shared.Message.assistant(
      id: itemId,
      sessionID: threadId,
      agent: "codex",
      modelID: context.modelId,
      providerID: context.providerId,
      time: null,
    );
  }

  List<BridgeSseEvent> _messageEvents({
    required String threadId,
    required String itemId,
    required shared.Message message,
    required PluginMessagePartType partType,
    required String partSuffix,
    required String? text,
  }) {
    return [
      BridgeSseMessageUpdated(info: message.toJson()),
      BridgeSseMessagePartUpdated(
        part: PluginMessagePart(
          id: "$itemId-$partSuffix",
          sessionID: threadId,
          messageID: itemId,
          type: partType,
          text: text ?? "",
          tool: null,
          state: null,
          prompt: null,
          description: null,
          agent: null,
          agentName: null,
          attempt: null,
          retryError: null,
        ),
      ),
    ];
  }

  shared.Session _threadToSession(
    CodexStartedThread thread,
    CodexEventContext context,
  ) {
    final created = thread.createdAtSeconds;
    final updated = thread.updatedAtSeconds;
    return shared.Session(
      id: thread.id,
      pluginId: context.pluginId,
      projectID: context.projectId,
      directory: context.projectId,
      parentID: null,
      title: thread.title,
      time: created == null || updated == null
          ? null
          : shared.SessionTime(
              created: (created * 1000).round(),
              updated: (updated * 1000).round(),
              archived: null,
            ),
      pullRequest: null,
      promptDefaults: null,
    );
  }

  shared.Session _minimalSession({
    required String id,
    required String? title,
    required CodexEventContext context,
  }) {
    return shared.Session(
      id: id,
      pluginId: context.pluginId,
      projectID: context.projectId,
      directory: context.projectId,
      parentID: null,
      title: title,
      time: null,
      pullRequest: null,
      promptDefaults: null,
    );
  }
}
