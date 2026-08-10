import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _sessionId = "11111111-2222-4333-8444-555555555555";

void main() {
  group("ClaudeHistoryMapper", () {
    late Directory temp;
    late ClaudeTranscriptCatalogRepository transcripts;
    late ClaudeHistoryMapper mapper;

    setUp(() {
      temp = Directory.systemTemp.createTempSync("claude-history-mapper-");
      transcripts = ClaudeTranscriptCatalogRepository(
        transcriptApi: ClaudeTranscriptApi(environment: {"CLAUDE_CONFIG_DIR": temp.path}),
      );
      mapper = const ClaudeHistoryMapper(content: ClaudeContentMapper());
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test("replays ordered user and grouped assistant messages", () async {
      _writeTranscript(
        temp: temp,
        records: [
          _messageRecord(
            type: "user",
            uuid: "user-uuid",
            timestamp: "2026-08-09T10:00:00Z",
            content: [
              {"type": "text", "text": "question"},
              {
                "type": "image",
                "source": {"type": "base64", "media_type": "image/png", "data": "AA=="},
              },
            ],
          ),
          _messageRecord(
            type: "assistant",
            uuid: "assistant-record-1",
            timestamp: "2026-08-09T10:00:01Z",
            messageId: "assistant-message-id",
            model: "claude-test-model",
            content: [
              {"type": "thinking", "thinking": "reasoning", "signature": "opaque"},
            ],
          ),
          _messageRecord(
            type: "assistant",
            uuid: "assistant-record-2",
            timestamp: "2026-08-09T10:00:02Z",
            messageId: "assistant-message-id",
            model: "claude-test-model",
            content: [
              {"type": "tool_use", "id": "toolu-1", "name": "Read", "input": <String, Object?>{}},
            ],
          ),
          _messageRecord(
            type: "assistant",
            uuid: "assistant-record-3",
            timestamp: "2026-08-09T10:00:03Z",
            messageId: "assistant-message-id",
            model: "claude-test-model",
            content: [
              {"type": "text", "text": "answer"},
            ],
          ),
          _messageRecord(
            type: "user",
            uuid: "tool-result-record",
            timestamp: "2026-08-09T10:00:04Z",
            content: [
              {"type": "tool_result", "tool_use_id": "toolu-1", "content": "file contents"},
            ],
          ),
          {
            "type": "attachment",
            "sessionId": _sessionId,
            "uuid": "context-record",
            "timestamp": "2026-08-09T10:00:05Z",
            "attachment": {"type": "directory", "content": "private context"},
          },
        ],
      );

      final messages = mapper.map(
        sessionId: _sessionId,
        records: await transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
      );

      expect(messages, hasLength(2));
      final user = messages[0];
      expect(user.info, isA<PluginMessageUser>());
      expect(user.info.id, "user-uuid");
      expect(user.info.time?.created, DateTime.parse("2026-08-09T10:00:00Z").millisecondsSinceEpoch);
      expect(user.parts.map((part) => part.type), [PluginMessagePartType.text, PluginMessagePartType.file]);

      final assistant = messages[1];
      expect(assistant.info, isA<PluginMessageAssistant>());
      expect(assistant.info.id, "assistant-message-id");
      expect((assistant.info as PluginMessageAssistant).agent, "claude");
      expect((assistant.info as PluginMessageAssistant).modelID, "claude-test-model");
      expect((assistant.info as PluginMessageAssistant).providerID, "anthropic");
      expect(assistant.info.time?.created, DateTime.parse("2026-08-09T10:00:01Z").millisecondsSinceEpoch);
      expect(assistant.info.time?.completed, isNull);
      expect(assistant.parts.map((part) => part.type), [
        PluginMessagePartType.reasoning,
        PluginMessagePartType.tool,
        PluginMessagePartType.text,
      ]);
      final tool = assistant.parts[1];
      expect(tool.id, "toolu-1");
      expect(tool.tool, "Read");
      expect(tool.state?.status, PluginToolStatus.completed);
      expect(tool.state?.output, "file contents");
      expect(
        assistant.parts,
        everyElement(
          predicate<PluginMessagePart>((part) {
            return part.sessionID == _sessionId && part.messageID == "assistant-message-id";
          }),
        ),
      );
    });

    test("skips sidechain, metadata, transcript-only, and unsupported records", () async {
      _writeTranscript(
        temp: temp,
        records: [
          _messageRecord(type: "user", uuid: "sidechain", content: "hidden", isSidechain: true),
          _messageRecord(type: "user", uuid: "meta", content: "hidden", isMeta: true),
          _messageRecord(
            type: "user",
            uuid: "transcript-only",
            content: "hidden",
            isVisibleInTranscriptOnly: true,
          ),
          _messageRecord(type: "user", uuid: "malformed", content: 42),
          _messageRecord(
            type: "assistant",
            uuid: "malformed-assistant",
            messageId: "malformed-assistant-message",
            content: 42,
          ),
          _messageRecord(
            type: "assistant",
            uuid: "record-id-is-not-a-message-id",
            content: [
              {"type": "text", "text": "hidden"},
            ],
          ),
          {"type": "future-record", "sessionId": _sessionId},
        ],
      );

      expect(
        mapper.map(
          sessionId: _sessionId,
          records: await transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
        ),
        isEmpty,
      );
    });

    test("does not convert a missing transcript into empty history", () async {
      expect(
        () => transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
        throwsA(isA<StateError>()),
      );
    });
  });
}

Map<String, Object?> _messageRecord({
  required String type,
  required String uuid,
  required Object? content,
  String timestamp = "2026-08-09T10:00:00Z",
  String? messageId,
  String? model,
  bool? isSidechain,
  bool? isMeta,
  bool? isVisibleInTranscriptOnly,
}) => {
  "type": type,
  "sessionId": _sessionId,
  "uuid": uuid,
  "timestamp": timestamp,
  "isSidechain": ?isSidechain,
  "isMeta": ?isMeta,
  "isVisibleInTranscriptOnly": ?isVisibleInTranscriptOnly,
  "message": {"id": ?messageId, "model": ?model, "content": content},
};

void _writeTranscript({required Directory temp, required List<Map<String, Object?>> records}) {
  final project = Directory(p.join(temp.path, "projects", "-workspace"))..createSync(recursive: true);
  File(p.join(project.path, "$_sessionId.jsonl")).writeAsStringSync(
    records.map(jsonEncode).join("\n"),
  );
}
