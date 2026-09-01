import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/claude_tool_use_result.dart";
import "repositories/mappers/claude_content_mapper.dart";
import "repositories/models/claude_transcript_record.dart";
import "repositories/trackers/claude_tool_tracker.dart";

/// Maps Claude's persisted transcript into the same neutral message shapes used
/// by live stream events.
final class const ClaudeHistoryMapper({
  required final ClaudeContentMapper _content,
}) {
  /// [residentTaskToolUseIds] names the sub-agent tasks the session's current
  /// resident process is still running. Any other replayed task that never
  /// reached a terminal record is dead — sub-agents die with their process —
  /// and renders as cancelled.
  ///
  /// [agentId] selects child mode: a sub-agent transcript's records are
  /// sidechain records stamped with the **parent's** session id, so they are
  /// attributed by agent id instead of the root's session-id cross-check.
  List<PluginMessageWithParts> map({
    required String sessionId,
    required String? agentId,
    required List<ClaudeTranscriptRecord> records,
    required Set<String> residentTaskToolUseIds,
  }) {
    bool skip(ClaudeTranscriptAttributedRecord record) => switch (agentId) {
      null => (record.isSidechain ?? false) || (record.sessionId != null && record.sessionId != sessionId),
      final agentId => record.agentId != agentId,
    };
    final entries = <_ClaudeHistoryEntry>[];
    final assistantsByMessageId = <String, _AssistantHistoryMessage>{};
    final assistantsByToolId = <String, _AssistantHistoryMessage>{};
    // Task lifecycle replays through the same tracker the live path uses, so
    // terminal precedence has exactly one implementation.
    final tasks = ClaudeToolTracker();

    for (final record in records) {
      switch (record) {
        case ClaudeTranscriptAssistantRecord():
          if (skip(record)) continue;
          final blocks = _content.map(content: record.content);
          if (_content.containsInternalCommandOutput(blocks: blocks)) continue;
          final assistant = assistantsByMessageId.putIfAbsent(record.id, () {
            final created = _AssistantHistoryMessage(
              id: record.id,
              timestamp: record.timestamp,
              model: record.model,
              variant: record.effort?.wireValue,
            );
            entries.add(created);
            return created;
          });
          assistant.content.add(record.content);
          assistant.model ??= record.model;
          assistant.variant ??= record.effort?.wireValue;
          for (var index = 0; index < blocks.length; index++) {
            if (blocks[index] case ClaudeMappedToolUseContentBlock(:final id, :final name, :final input)) {
              assistantsByToolId[id] = assistant;
              tasks.upsertCompleteBlock(
                sessionId: sessionId,
                messageId: record.id,
                blockIndex: index,
                toolId: id,
                name: name,
                input: input,
              );
            }
          }
        case ClaudeTranscriptUserRecord():
          if (skip(record) || record.isMeta || record.isVisibleInTranscriptOnly) {
            continue;
          }
          final blocks = _content.map(content: record.content);
          if (_content.containsInternalCommandOutput(blocks: blocks)) continue;
          final results = [
            for (final block in blocks)
              if (block is ClaudeMappedToolResultContentBlock) block,
          ];
          if (results.isNotEmpty) {
            final typedResult = results.length == 1 ? record.toolUseResult : const ClaudeToolUseResultAbsent();
            final toolResults = <ClaudeMappedToolResultContentBlock>[];
            for (final result in results) {
              if (!tasks.isKnownTask(sessionId: sessionId, toolUseId: result.toolUseId)) {
                toolResults.add(result);
                continue;
              }
              tasks.complete(
                sessionId: sessionId,
                toolId: result.toolUseId,
                output: result.output,
                isError: result.isError,
                attachments: result.attachments,
                result: typedResult,
              );
            }
            final targets = {
              for (final result in toolResults) ?assistantsByToolId[result.toolUseId],
            };
            if (targets.length == 1) targets.single.content.add(record.content);
            continue;
          }
          if (blocks.whereType<ClaudeMappedTaskNotificationContentBlock>().firstOrNull case final block?
              when tasks.isKnownTask(sessionId: sessionId, toolUseId: block.notification.toolUseId)) {
            tasks.taskNotified(
              sessionId: sessionId,
              toolUseId: block.notification.toolUseId,
              taskId: block.notification.taskId,
              status: block.notification.status,
              summary: block.notification.summary,
              result: block.notification.result,
            );
            continue;
          }
          // The CLI's own delivery of a task outcome to the model, never a
          // user-authored message, even when its envelope names no task here.
          if (record.isTaskNotification) continue;

          final parts = _content.mapParts(
            content: _content.visibleUserContent(content: record.content),
            sessionId: sessionId,
            messageId: record.id,
          );
          if (!parts.any((part) => part.type.isVisible)) continue;
          entries.add(
            _UserHistoryMessage(
              message: PluginMessageWithParts(
                info: PluginMessage.user(
                  id: record.id,
                  sessionID: sessionId,
                  agent: null,
                  time: _messageTime(record.timestamp),
                  promptId: null,
                ),
                parts: parts,
              ),
            ),
          );
        case ClaudeTranscriptContextRecord() ||
            ClaudeTranscriptUnreplayableMessageRecord() ||
            ClaudeTranscriptTitleRecord() ||
            ClaudeTranscriptUnknownRecord():
          continue;
      }
    }

    for (final toolUseId in tasks.runningTaskToolUseIds(sessionId: sessionId).difference(residentTaskToolUseIds)) {
      tasks.cancelTask(sessionId: sessionId, toolUseId: toolUseId);
    }

    final messages = <PluginMessageWithParts>[];
    for (final entry in entries) {
      switch (entry) {
        case _UserHistoryMessage(:final message):
          messages.add(message);
        case _AssistantHistoryMessage():
          final message = _buildAssistant(entry: entry, sessionId: sessionId, tasks: tasks);
          if (message != null) messages.add(message);
      }
    }
    return messages;
  }

  PluginMessageWithParts? _buildAssistant({
    required _AssistantHistoryMessage entry,
    required String sessionId,
    required ClaudeToolTracker tasks,
  }) {
    final mapped = _content.mapParts(
      content: entry.content,
      sessionId: sessionId,
      messageId: entry.id,
    );
    final parts = <PluginMessagePart>[];
    final toolIndexById = <String, int>{};
    for (final part in mapped) {
      if (part.type != PluginMessagePartType.tool) {
        parts.add(part);
        continue;
      }
      final existingIndex = toolIndexById[part.id];
      if (existingIndex == null) {
        toolIndexById[part.id] = parts.length;
        final task = tasks.task(sessionId: sessionId, toolUseId: part.id);
        if (task == null) {
          parts.add(part);
        } else if (task.toPart(sessionId: sessionId) case final subtask?) {
          parts.add(subtask);
        }
        continue;
      }
      if (part case PluginMessagePartTool(:final state) when state.status != PluginToolStatus.pending) {
        if (parts[existingIndex] case final PluginMessagePartTool existing) {
          parts[existingIndex] = existing.copyWith(state: state);
        }
      }
    }
    if (!parts.any((part) => part.type.isVisible)) return null;
    return PluginMessageWithParts(
      info: PluginMessage.assistant(
        id: entry.id,
        sessionID: sessionId,
        agent: "claude",
        modelID: entry.model,
        providerID: "anthropic",
        variant: entry.variant,
        sender: PluginMessageSender.agent,
        time: _messageTime(entry.timestamp),
      ),
      parts: List.unmodifiable(parts),
    );
  }
}

sealed class const _ClaudeHistoryEntry();

final class const _UserHistoryMessage({required final PluginMessageWithParts message}) extends _ClaudeHistoryEntry;

final class _AssistantHistoryMessage({
  required final String id,
  required final DateTime? timestamp,
  required var String? model,
  required var String? variant,
}) extends _ClaudeHistoryEntry {
  final List<Object?> content = [];
}

PluginMessageTime? _messageTime(DateTime? timestamp) =>
    timestamp == null ? null : PluginMessageTime(created: timestamp.millisecondsSinceEpoch, completed: null);
