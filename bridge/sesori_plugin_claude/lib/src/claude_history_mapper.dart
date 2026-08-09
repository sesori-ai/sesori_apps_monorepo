import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "repositories/claude_transcript_catalog_repository.dart";
import "repositories/mappers/claude_content_mapper.dart";
import "repositories/models/claude_transcript_record.dart";

/// Maps Claude's persisted transcript into the same neutral message shapes used
/// by live stream events.
final class ClaudeHistoryMapper {
  const ClaudeHistoryMapper({
    required ClaudeContentMapper content,
    required ClaudeTranscriptCatalogRepository transcripts,
  }) : _content = content,
       _transcripts = transcripts;

  final ClaudeContentMapper _content;
  final ClaudeTranscriptCatalogRepository _transcripts;

  Future<List<PluginMessageWithParts>> map({required String sessionId}) async {
    final List<ClaudeTranscriptRecord> records;
    try {
      records = await _transcripts.readTranscriptRecordsInIsolate(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException(
          "read Claude session transcript",
          message: "history read for $sessionId failed",
          cause: error,
        ),
        stackTrace,
      );
    }

    final entries = <_ClaudeHistoryEntry>[];
    final assistantsByMessageId = <String, _AssistantHistoryMessage>{};
    final assistantsByToolId = <String, _AssistantHistoryMessage>{};

    for (final record in records) {
      if (record is! ClaudeTranscriptMessageRecord ||
          record.isSidechain == true ||
          (record.sessionId != null && record.sessionId != sessionId) ||
          record.isMeta == true ||
          record.isVisibleInTranscriptOnly == true) {
        continue;
      }

      final blocks = _content.map(content: record.content);
      switch (record.kind) {
        case ClaudeTranscriptMessageKind.assistant:
          final messageId = _nonEmpty(record.messageId) ?? _nonEmpty(record.uuid);
          if (messageId == null) continue;
          final assistant = assistantsByMessageId.putIfAbsent(messageId, () {
            final created = _AssistantHistoryMessage(
              id: messageId,
              timestamp: record.timestamp,
              model: _nonEmpty(record.model),
            );
            entries.add(created);
            return created;
          });
          assistant.content.add(record.content);
          assistant.model ??= _nonEmpty(record.model);
          for (final block in blocks) {
            if (block case ClaudeMappedToolUseContentBlock(:final id)) {
              assistantsByToolId[id] = assistant;
            }
          }
        case ClaudeTranscriptMessageKind.user:
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

          final messageId = _nonEmpty(record.uuid);
          if (messageId == null) continue;
          final parts = _content.mapParts(
            content: record.content,
            sessionId: sessionId,
            messageId: messageId,
          );
          if (!parts.any((part) => part.type.isVisible)) continue;
          entries.add(
            _UserHistoryMessage(
              message: PluginMessageWithParts(
                info: PluginMessage.user(
                  id: messageId,
                  sessionID: sessionId,
                  agent: null,
                  time: _messageTime(record.timestamp),
                ),
                parts: parts,
              ),
            ),
          );
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
      final state = part.state;
      if (state != null && state.status != PluginToolStatus.pending) {
        parts[existingIndex] = parts[existingIndex].copyWith(state: state);
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
        time: _messageTime(entry.timestamp),
      ),
      parts: List.unmodifiable(parts),
    );
  }
}

sealed class _ClaudeHistoryEntry {
  const _ClaudeHistoryEntry();
}

final class _UserHistoryMessage extends _ClaudeHistoryEntry {
  const _UserHistoryMessage({required this.message});

  final PluginMessageWithParts message;
}

final class _AssistantHistoryMessage extends _ClaudeHistoryEntry {
  _AssistantHistoryMessage({required this.id, required this.timestamp, required this.model});

  final String id;
  final DateTime? timestamp;
  String? model;
  final List<Object?> content = [];
}

PluginMessageTime? _messageTime(DateTime? timestamp) =>
    timestamp == null ? null : PluginMessageTime(created: timestamp.millisecondsSinceEpoch, completed: null);

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
