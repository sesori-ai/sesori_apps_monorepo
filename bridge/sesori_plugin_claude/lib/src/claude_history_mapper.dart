import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "repositories/mappers/claude_content_mapper.dart";
import "repositories/models/claude_transcript_record.dart";

/// Maps Claude's persisted transcript into the same neutral message shapes used
/// by live stream events.
final class const ClaudeHistoryMapper({
  required final ClaudeContentMapper _content,
}) {
  List<PluginMessageWithParts> map({
    required String sessionId,
    required List<ClaudeTranscriptRecord> records,
  }) {
    final entries = <_ClaudeHistoryEntry>[];
    final assistantsByMessageId = <String, _AssistantHistoryMessage>{};
    final assistantsByToolId = <String, _AssistantHistoryMessage>{};

    for (final record in records) {
      switch (record) {
        case ClaudeTranscriptAssistantRecord():
          if (_skipRecord(record: record, sessionId: sessionId)) continue;
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
          for (final block in blocks) {
            if (block case ClaudeMappedToolUseContentBlock(:final id)) {
              assistantsByToolId[id] = assistant;
            }
          }
        case ClaudeTranscriptUserRecord():
          if (_skipRecord(record: record, sessionId: sessionId) || record.isMeta || record.isVisibleInTranscriptOnly) {
            continue;
          }
          final blocks = _content.map(content: record.content);
          if (_content.containsInternalCommandOutput(blocks: blocks)) continue;
          final results = [
            for (final block in blocks)
              if (block is ClaudeMappedToolResultContentBlock) block,
          ];
          if (results.isNotEmpty) {
            final targets = {
              for (final result in results) ?assistantsByToolId[result.toolUseId],
            };
            if (targets.length == 1) targets.single.content.add(record.content);
            continue;
          }

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

    final messages = <PluginMessageWithParts>[];
    for (final entry in entries) {
      switch (entry) {
        case _UserHistoryMessage(:final message):
          messages.add(message);
        case _AssistantHistoryMessage():
          final message = _buildAssistant(entry: entry, sessionId: sessionId);
          if (message != null) messages.add(message);
      }
    }
    return messages;
  }

  PluginMessageWithParts? _buildAssistant({
    required _AssistantHistoryMessage entry,
    required String sessionId,
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
        parts.add(part);
        continue;
      }
      if (part case PluginMessagePartTool(:final state) when state.status != PluginToolStatus.pending) {
        final existing = parts[existingIndex] as PluginMessagePartTool;
        parts[existingIndex] = existing.copyWith(state: state);
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
        time: _messageTime(entry.timestamp),
      ),
      parts: List.unmodifiable(parts),
    );
  }
}

bool _skipRecord({required ClaudeTranscriptAttributedRecord record, required String sessionId}) =>
    (record.isSidechain ?? false) || (record.sessionId != null && record.sessionId != sessionId);

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
