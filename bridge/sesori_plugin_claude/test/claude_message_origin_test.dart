import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _sessionId = "11111111-2222-4333-8444-555555555555";
const _timestamp = "2026-09-25T10:00:00Z";
const _peerText = "Another Claude session sent a message:\nSynthetic plugin automation report.";

void main() {
  for (final fixture in [
    (name: "peer", raw: {"kind": "peer", "from": "unknown"}, expected: ClaudeMessageOriginKind.peer),
    (name: "task outcome", raw: {"kind": "task-notification"}, expected: ClaudeMessageOriginKind.taskNotification),
    (name: "human", raw: {"kind": "human"}, expected: ClaudeMessageOriginKind.unknown),
    (name: "channel", raw: {"kind": "channel", "server": "chat"}, expected: ClaudeMessageOriginKind.unknown),
    (name: "future", raw: {"kind": "future-origin"}, expected: ClaudeMessageOriginKind.unknown),
    (name: "absent", raw: null, expected: ClaudeMessageOriginKind.unknown),
    (name: "non-object", raw: "peer", expected: ClaudeMessageOriginKind.unknown),
    (name: "wrong kind type", raw: {"kind": 42}, expected: ClaudeMessageOriginKind.unknown),
  ]) {
    test("live and transcript boundaries decode ${fixture.name} origin", () {
      final frame = _user(content: _peerText, origin: fixture.raw);
      final live = ClaudeStreamMessage.parse(frame) as ClaudeUserMessage;
      final stored = ClaudeTranscriptRecordDto.fromJson(frame);
      expect(live.originKind, fixture.expected);
      expect(stored.originKind, fixture.expected);
    });
  }

  group("automation attribution", () {
    late Directory temp;
    late ClaudeEventDispatcher live;
    late ClaudeTranscriptCatalogRepository transcripts;
    const history = ClaudeHistoryMapper(content: ClaudeContentMapper());

    setUp(() {
      temp = Directory.systemTemp.createTempSync("claude-origin-");
      transcripts = ClaudeTranscriptCatalogRepository(
        transcriptApi: ClaudeTranscriptApi(environment: {"CLAUDE_CONFIG_DIR": temp.path}),
      );
      live = ClaudeEventDispatcher(
        content: const ClaudeContentMapper(),
        tools: ClaudeToolTracker(),
        catalogModelId: ({required apiModel}) => null,
      );
    });
    tearDown(() => temp.deleteSync(recursive: true));

    Future<List<PluginMessageWithParts>> replay({required List<Map<String, Object?>> records}) async {
      final project = Directory(p.join(temp.path, "projects", "fixture"))..createSync(recursive: true);
      File(p.join(project.path, "$_sessionId.jsonl")).writeAsStringSync(records.map(jsonEncode).join("\n"));
      return history.map(
        sessionId: _sessionId,
        agentId: null,
        records: await transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
        residentTaskToolUseIds: const {},
        catalogModelId: null,
      );
    }

    test("native peer shape maps to identical automation live and after replay", () async {
      // Shape observed from Claude 2.1.281's socket with a synthetic MCP sender.
      // No real session content or identifiers are used in this fixture.
      final frame = _user(content: _peerText, origin: {"kind": "peer", "from": "unknown"});
      final events = live.map(message: ClaudeStreamMessage.parse(frame));
      final liveInfo = events.whereType<BridgeSseMessageUpdated>().single.info as PluginMessageAssistant;
      final stored = (await replay(records: [frame])).single;

      expect(liveInfo.sender, PluginMessageSender.system);
      expect(liveInfo.agent, isNull);
      expect(liveInfo.modelID, isNull);
      expect(liveInfo.providerID, isNull);
      expect(liveInfo.variant, isNull);
      expect(liveInfo.id, "fixture-user");
      expect(liveInfo.toJson(), stored.info.toJson());
      expect(events.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part).toList(), stored.parts);
      expect(stored.parts.single.text, _peerText);
    });

    test("peer content is not stripped as bridge-authored user execution context", () async {
      const text = "[SYSTEM CONTEXT — IMPORTANT]\nSynthetic plugin content\n---\nRemaining content";
      final frame = _user(content: text, origin: {"kind": "peer"});
      final events = live.map(message: ClaudeStreamMessage.parse(frame));
      expect(events.whereType<BridgeSseMessagePartUpdated>().single.part.text, text);
      expect((await replay(records: [frame])).single.parts.single.text, text);
    });

    test("text and external userType never turn ordinary prompts into automation", () async {
      for (final origin in [
        null,
        {"kind": "human"},
        {"kind": "channel"},
        {"kind": "future-origin"},
      ]) {
        final frame = _user(content: "[PR Monitor] This is a human's quoted example.", origin: origin, isMeta: false);
        final events = live.map(message: ClaudeStreamMessage.parse(frame));
        expect(events.whereType<BridgeSseMessageUpdated>().single.info, isA<PluginMessageUser>());
        expect((await replay(records: [frame])).single.info, isA<PluginMessageUser>());
      }
    });

    test("correlated prompt replay retains its user replacement and prompt id", () {
      final frame = _user(content: "A queued prompt", origin: null, isMeta: false);
      final events = live.mapPromptReplay(
        message: ClaudeStreamMessage.parse(frame) as ClaudeUserMessage,
        promptId: "queued-prompt",
      );
      final info = events.whereType<BridgeSseMessageUpdated>().single.info as PluginMessageUser;
      expect(info.promptId, "queued-prompt");
    });

    test("peer provenance takes precedence over an advisory prompt id", () {
      final frame = _user(content: _peerText, origin: {"kind": "peer"});
      final events = live.mapPromptReplay(
        message: ClaudeStreamMessage.parse(frame) as ClaudeUserMessage,
        promptId: "queued-prompt",
      );
      final info = events.whereType<BridgeSseMessageUpdated>().single.info as PluginMessageAssistant;
      expect(info.sender, PluginMessageSender.system);
    });

    test("history permits peer metadata without exposing unrelated hidden records", () async {
      final peer = _user(content: _peerText, origin: {"kind": "peer"});
      final records = [
        _user(content: "Internal context", origin: null),
        _user(content: "Unknown context", origin: {"kind": "future-origin"}),
        _user(content: "Hidden task outcome", origin: {"kind": "task-notification"}),
        {...peer, "uuid": "sidechain", "isSidechain": true},
        {...peer, "uuid": "transcript-only", "isVisibleInTranscriptOnly": true},
        {...peer, "uuid": "wrong-session", "sessionId": "different-session"},
        _user(content: "", origin: {"kind": "peer"}),
        _user(content: "<local-command-stdout>internal</local-command-stdout>", origin: {"kind": "peer"}),
        _user(
          content: [
            {"type": "tool_result", "tool_use_id": "unknown-tool", "content": "tool output"},
          ],
          origin: {"kind": "peer"},
        ),
        peer,
      ];
      final stored = await replay(records: records);
      expect(stored, hasLength(1));
      expect((stored.single.info as PluginMessageAssistant).sender, PluginMessageSender.system);
      expect(stored.single.parts.single.text, _peerText);
    });

    test("synthetic peer message cannot consume the pending compaction summary", () {
      live.map(
        message: ClaudeStreamMessage.parse({
          "type": "system",
          "subtype": "compact_boundary",
          "session_id": _sessionId,
        }),
      );
      final peer = live.map(
        message: ClaudeStreamMessage.parse(_user(content: _peerText, origin: {"kind": "peer"})),
      );
      final summary = live.map(
        message: ClaudeStreamMessage.parse(_user(content: "Compacted history", origin: null)),
      );
      expect(
        (peer.whereType<BridgeSseMessageUpdated>().single.info as PluginMessageAssistant).sender,
        PluginMessageSender.system,
      );
      expect(peer.whereType<BridgeSseMessagePartUpdated>().single.part.type, PluginMessagePartType.text);
      expect(summary.whereType<BridgeSseMessagePartUpdated>().single.part.type, PluginMessagePartType.compaction);
    });
  });
}

Map<String, Object?> _user({required Object? content, required Object? origin, bool isMeta = true}) => {
  "type": "user",
  "session_id": _sessionId,
  "sessionId": _sessionId,
  "uuid": "fixture-user",
  "timestamp": _timestamp,
  "isMeta": isMeta,
  "isSynthetic": true,
  "isSidechain": false,
  "userType": "external",
  "origin": origin,
  "message": {"role": "user", "content": content},
};
