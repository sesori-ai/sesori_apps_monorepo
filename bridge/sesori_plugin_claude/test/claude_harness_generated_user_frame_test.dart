import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _sessionId = "11111111-2222-4333-8444-555555555555";
const _timestamp = "2026-09-25T10:00:00Z";

/// A short stand-in for the whole `SKILL.md` body the CLI injects as its own
/// `user` frame when a skill loads. No real skill content is used.
const _skillBody =
    "Base directory for this skill: /tmp/fixture/.claude/skills/fixture\n\n"
    "# Fixture skill\n\nSynthetic instructions.\n\n<ARGUMENTS></ARGUMENTS>";
const _peerText = "Another Claude session sent a message:\nSynthetic peer report.";
const _envelope =
    "<task-notification>\n<task-id>task-1</task-id>\n<tool-use-id>toolu-agent</tool-use-id>\n"
    "<output-file>/tmp/task.output</output-file>\n<status>completed</status>\n"
    "<summary>Synthetic task finished</summary>\n<result>Synthetic result</result>\n</task-notification>";

void main() {
  late Directory temp;
  late ClaudeEventDispatcher live;
  late ClaudeTranscriptCatalogRepository transcripts;
  const history = ClaudeHistoryMapper(content: ClaudeContentMapper());

  setUp(() {
    temp = Directory.systemTemp.createTempSync("claude-harness-frame-");
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

  /// Maps [frames] live, returning the events of the last frame.
  List<BridgeSseEvent> mapLive({required List<Map<String, Object?>> frames}) {
    var events = const <BridgeSseEvent>[];
    for (final frame in frames) {
      events = live.map(message: ClaudeStreamMessage.parse(frame));
    }
    return events;
  }

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

  // The stream spells the flag `isSynthetic`; the transcript spells it `isMeta`;
  // a replayed frame can carry both. Every spelling must hide the frame live.
  for (final flags in [
    {"isSynthetic": true},
    {"isMeta": true},
    {"isSynthetic": true, "isMeta": true},
  ]) {
    test("hides a live skill body flagged ${flags.keys.join(" and ")}", () {
      final events = mapLive(
        frames: [
          {..._user(uuid: "skill-body", content: _skillBody, origin: null), ...flags},
        ],
      );
      expect(events, isEmpty);
    });
  }

  test("hides a replayed skill body the transcript flagged as metadata", () async {
    final stored = await replay(
      records: [
        {..._user(uuid: "skill-body", content: _skillBody, origin: null), "isMeta": true},
      ],
    );
    expect(stored, isEmpty);
  });

  test("keeps a peer injection the harness also flagged, live and after replay", () async {
    final frame = {
      ..._user(uuid: "peer-report", content: _peerText, origin: const {"kind": "peer", "from": "unknown"}),
      "isSynthetic": true,
      "isMeta": true,
    };
    final events = mapLive(frames: [frame]);
    final info = events.whereType<BridgeSseMessageUpdated>().single.info as PluginMessageAssistant;
    expect(info.sender, PluginMessageSender.system);
    expect(events.whereType<BridgeSseMessagePartUpdated>().single.part.text, _peerText);

    final stored = await replay(records: [frame]);
    expect(stored.single.parts.single.text, _peerText);
  });

  test("still completes a tool from a flagged tool_result frame", () {
    final events = mapLive(
      frames: [
        _assistant(toolUseId: "toolu-bash", name: "Bash", input: const {"command": "true"}),
        {
          ..._user(
            uuid: "result-frame",
            content: const [
              {"type": "tool_result", "tool_use_id": "toolu-bash", "content": "done"},
            ],
            origin: null,
          ),
          "isSynthetic": true,
        },
      ],
    );
    final tool = events.whereType<BridgeSseMessagePartUpdated>().single.part as PluginMessagePartTool;
    expect(tool.id, "toolu-bash");
    expect(tool.state.status, PluginToolStatus.completed);
  });

  test("still finalizes a background task from a flagged notification envelope", () {
    final events = mapLive(
      frames: [
        _assistant(toolUseId: "toolu-agent", name: "Agent", input: _agentInput),
        _launchResult(toolUseId: "toolu-agent"),
        {..._user(uuid: "notification", content: _envelope, origin: null), "isSynthetic": true},
      ],
    );
    final subtask = events.whereType<BridgeSseMessagePartUpdated>().single.part as PluginMessagePartSubtask;
    expect(subtask.taskState?.status, PluginToolStatus.completed);
    expect(subtask.taskState?.output, "Synthetic result");
  });

  test("still renders an unflagged typed prompt, live and after replay", () async {
    final frame = _user(uuid: "typed-prompt", content: "Run the fixture skill", origin: null);
    final events = mapLive(frames: [frame]);
    expect(events.whereType<BridgeSseMessageUpdated>().single.info, isA<PluginMessageUser>());
    expect(events.whereType<BridgeSseMessagePartUpdated>().single.part.text, "Run the fixture skill");
    expect((await replay(records: [frame])).single.parts.single.text, "Run the fixture skill");
  });
}

const _agentInput = {"description": "Synthetic", "prompt": "Synthetic prompt", "subagent_type": "general-purpose"};

Map<String, Object?> _assistant({required String toolUseId, required String name, required Object? input}) => {
  "type": "assistant",
  "session_id": _sessionId,
  "sessionId": _sessionId,
  "uuid": "assistant-$toolUseId",
  "timestamp": _timestamp,
  "message": {
    "id": "msg-$toolUseId",
    "model": "claude-opus-5",
    "content": [
      {"type": "tool_use", "id": toolUseId, "name": name, "input": input},
    ],
  },
};

/// The launch acknowledgement carrying the agent's typed async result.
Map<String, Object?> _launchResult({required String toolUseId}) => {
  "type": "user",
  "session_id": _sessionId,
  "sessionId": _sessionId,
  "uuid": "launch-$toolUseId",
  "timestamp": _timestamp,
  "message": {
    "role": "user",
    "content": [
      {"type": "tool_result", "tool_use_id": toolUseId, "content": "Launched in background."},
    ],
  },
  "tool_use_result": const {"isAsync": true, "status": "async_launched", "agentId": "task-1"},
};

Map<String, Object?> _user({required String uuid, required Object? content, required Object? origin}) => {
  "type": "user",
  "session_id": _sessionId,
  "sessionId": _sessionId,
  "uuid": uuid,
  "timestamp": _timestamp,
  "isSidechain": false,
  "userType": "external",
  "origin": origin,
  "message": {"role": "user", "content": content},
};
