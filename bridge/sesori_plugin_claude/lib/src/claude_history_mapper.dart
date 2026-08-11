import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "repositories/mappers/claude_content_mapper.dart";
import "repositories/models/claude_transcript_record.dart";

/// Maps Claude's persisted transcript into the same neutral message shapes used
/// by live stream events.
final class ClaudeHistoryMapper {
  const ClaudeHistoryMapper({
    required ClaudeContentMapper content,
  }) : _content = content;

  final ClaudeContentMapper _content;

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
          final assistant = assistantsByMessageId.putIfAbsent(record.id, () {
            final created = _AssistantHistoryMessage(
              id: record.id,
              timestamp: record.timestamp,
              model: record.model,
            );
            entries.add(created);
            return created;
          });
          assistant.content.add(record.content);
          assistant.model ??= record.model;
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
            content: _visibleUserContent(record.content),
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

bool _skipRecord({required ClaudeTranscriptAttributedRecord record, required String sessionId}) =>
    record.isSidechain == true || (record.sessionId != null && record.sessionId != sessionId);

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

Object? _visibleUserContent(Object? content) {
  if (content is! List) return content;
  final visible = <Object?>[];
  for (final block in content) {
    if (block is Map && block["type"] == "text" && block["text"] is String) {
      final text = _stripBridgeContext(block["text"]! as String);
      if (text != null && text.isNotEmpty) visible.add({...block.cast<String, Object?>(), "text": text});
    } else {
      visible.add(block);
    }
  }
  return visible;
}

String? _stripBridgeContext(String text) {
  const marker = "[SYSTEM CONTEXT \u2014 IMPORTANT]";
  final markerIndex = text.indexOf(marker);
  if (markerIndex < 0) return text;
  final envelopeEnd = text.indexOf("\n---", markerIndex);
  if (envelopeEnd < 0) return text;
  final trailing = text.substring(envelopeEnd + "\n---".length).trim();
  if (markerIndex == 0) return trailing.isEmpty ? null : trailing;
  final prefix = text.substring(0, markerIndex).trimRight();
  if (!prefix.startsWith("/")) return text;
  return trailing.isEmpty ? prefix : "$prefix $trailing";
}
