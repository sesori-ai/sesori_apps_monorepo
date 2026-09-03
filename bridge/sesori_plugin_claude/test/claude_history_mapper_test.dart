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
            uuid: "model-command-user",
            content: const [
              {"type": "text", "text": "<command-name>/model</command-name>"},
            ],
          ),
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
            effort: "high",
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
            effort: "high",
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
            effort: "high",
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
        agentId: null,
        records: await transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
        residentTaskToolUseIds: const {},
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
      expect((assistant.info as PluginMessageAssistant).variant, "high");
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
      expect(tool.state.status, PluginToolStatus.completed);
      expect(tool.state.output, "file contents");
      expect(
        assistant.parts,
        everyElement(
          predicate<PluginMessagePart>((part) {
            return part.sessionID == _sessionId && part.messageID == "assistant-message-id";
          }),
        ),
      );
    });

    test("removes bridge worktree context from visible prompt and command history", () async {
      const context = """
[SYSTEM CONTEXT \u2014 IMPORTANT]
A dedicated git worktree and branch have been created for this session:
- Branch: private-branch
- Worktree path: /private/worktree
- Based on: main

IMPORTANT: Do NOT create new worktrees.

---
""";
      _writeTranscript(
        temp: temp,
        records: [
          _messageRecord(
            type: "user",
            uuid: "initial-user",
            timestamp: "2026-08-09T10:00:00Z",
            content: [
              {"type": "text", "text": context},
              {"type": "text", "text": "visible prompt"},
            ],
          ),
          _messageRecord(
            type: "user",
            uuid: "command-user",
            timestamp: "2026-08-09T10:00:01Z",
            content: [
              {"type": "text", "text": "/review ${context.trimRight()}\n\nvisible args"},
            ],
          ),
        ],
      );

      final messages = mapper.map(
        sessionId: _sessionId,
        agentId: null,
        records: await transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
        residentTaskToolUseIds: const {},
      );

      expect(messages.map((message) => message.parts.single.text), ["visible prompt", "/review visible args"]);
    });

    test("ignores an unknown historical effort", () async {
      _writeTranscript(
        temp: temp,
        records: [
          _messageRecord(
            type: "assistant",
            uuid: "assistant-record",
            messageId: "assistant-message-id",
            model: "claude-test-model",
            effort: "future-effort",
            content: "answer",
          ),
        ],
      );

      final messages = mapper.map(
        sessionId: _sessionId,
        agentId: null,
        records: await transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
        residentTaskToolUseIds: const {},
      );

      expect((messages.single.info as PluginMessageAssistant).variant, isNull);
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
          agentId: null,
          records: await transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
          residentTaskToolUseIds: const {},
        ),
        isEmpty,
      );
    });

    test("skips internal local command records", () async {
      _writeTranscript(
        temp: temp,
        records: [
          _messageRecord(
            type: "assistant",
            uuid: "model-command",
            messageId: "synthetic-message",
            model: "<synthetic>",
            content: const [
              {
                "type": "text",
                "text": "<local-command-stdout>Set model to haiku</local-command-stdout>",
              },
            ],
          ),
        ],
      );

      expect(
        mapper.map(
          sessionId: _sessionId,
          agentId: null,
          records: await transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
          residentTaskToolUseIds: const {},
        ),
        isEmpty,
      );
    });

    test("replays CLI API failures as one error instead of a synthetic assistant", () async {
      _writeTranscript(
        temp: temp,
        records: [
          _messageRecord(
            type: "assistant",
            uuid: "real-assistant-record",
            messageId: "real-assistant-message",
            model: "claude-test-model",
            content: const [
              {"type": "text", "text": "answer"},
            ],
          ),
          _messageRecord(
            type: "assistant",
            uuid: "api-error-record",
            messageId: "synthetic-error-message",
            model: "<synthetic>",
            isApiErrorMessage: true,
            apiErrorStatus: 429,
            error: "rate_limit",
            content: const [
              {"type": "text", "text": "You've hit your session limit"},
            ],
          ),
          _messageRecord(
            type: "assistant",
            uuid: "api-error-record-continuation",
            messageId: "synthetic-error-message",
            model: "<synthetic>",
            isApiErrorMessage: true,
            content: const [],
          ),
        ],
      );

      final messages = mapper.map(
        sessionId: _sessionId,
        agentId: null,
        records: await transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
        residentTaskToolUseIds: const {},
      );

      expect(messages, hasLength(2));
      final error = messages.last;
      expect(error.info, isA<PluginMessageError>());
      expect(error.info.id, "synthetic-error-message");
      expect((error.info as PluginMessageError).errorName, "api_error");
      expect((error.info as PluginMessageError).errorMessage, "You've hit your session limit");
      expect((error.info as PluginMessageError).modelID, "claude-test-model");
      expect((error.info as PluginMessageError).providerID, "anthropic");
      expect(error.parts, isEmpty);
    });

    test("uses the live fallback for a persisted API failure without text", () async {
      _writeTranscript(
        temp: temp,
        records: [
          _messageRecord(
            type: "assistant",
            uuid: "empty-api-error-record",
            messageId: "empty-synthetic-error-message",
            model: "<synthetic>",
            isApiErrorMessage: true,
            content: const [],
          ),
        ],
      );

      final messages = mapper.map(
        sessionId: _sessionId,
        agentId: null,
        records: await transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
        residentTaskToolUseIds: const {},
      );

      final error = messages.single.info as PluginMessageError;
      expect(error.errorMessage, "Claude Code could not complete the API request.");
    });

    test("reads the typed tool-use result and task-notification origin from the transcript", () async {
      _writeTranscript(
        temp: temp,
        records: [
          _messageRecord(
            type: "assistant",
            uuid: "agent-call",
            messageId: "agent-message",
            content: const [
              {
                "type": "tool_use",
                "id": "toolu-agent",
                "name": "Agent",
                "input": {"description": "Say hi", "prompt": "hi please"},
              },
            ],
          ),
          {
            ..._messageRecord(
              type: "user",
              uuid: "agent-launch",
              content: const [
                {"type": "tool_result", "tool_use_id": "toolu-agent", "content": "Async agent launched successfully."},
              ],
            ),
            "toolUseResult": {"isAsync": true, "status": "async_launched", "agentId": "abc123"},
          },
          {
            ..._messageRecord(
              type: "user",
              uuid: "agent-notify",
              content:
                  "<task-notification>\n<task-id>abc123</task-id>\n<tool-use-id>toolu-agent</tool-use-id>\n"
                  '<status>failed</status>\n<summary>Agent "Say hi" failed</summary>\n</task-notification>',
            ),
            "origin": {"kind": "task-notification"},
          },
        ],
      );

      final messages = mapper.map(
        sessionId: _sessionId,
        agentId: null,
        records: await transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
        residentTaskToolUseIds: const {},
      );

      final part = messages.single.parts.single as PluginMessagePartSubtask;
      expect(part.childSessionID, "agent-abc123");
      expect(part.taskState?.status, PluginToolStatus.error);
      expect(part.taskState?.error, 'Agent "Say hi" failed');
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
  String? effort,
  bool? isSidechain,
  bool? isMeta,
  bool? isVisibleInTranscriptOnly,
  bool? isApiErrorMessage,
  int? apiErrorStatus,
  String? error,
}) => {
  "type": type,
  "sessionId": _sessionId,
  "uuid": uuid,
  "timestamp": timestamp,
  "isSidechain": ?isSidechain,
  "isMeta": ?isMeta,
  "isVisibleInTranscriptOnly": ?isVisibleInTranscriptOnly,
  "isApiErrorMessage": ?isApiErrorMessage,
  "apiErrorStatus": ?apiErrorStatus,
  "error": ?error,
  "effort": ?effort,
  "message": {"id": ?messageId, "model": ?model, "content": content},
};

void _writeTranscript({required Directory temp, required List<Map<String, Object?>> records}) {
  final project = Directory(p.join(temp.path, "projects", "-workspace"))..createSync(recursive: true);
  File(p.join(project.path, "$_sessionId.jsonl")).writeAsStringSync(
    records.map(jsonEncode).join("\n"),
  );
}
