import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _sessionId = "11111111-2222-4333-8444-555555555555";
const _timestamp = "2026-09-25T10:00:00Z";
const _origin = {"kind": "task-notification"};

/// A short synthetic envelope in the CLI's shape; [toolUseId] null omits the tag.
String _envelope({required String? toolUseId, String status = "completed", String result = "Synthetic result"}) =>
    "<task-notification>\n<task-id>task-1</task-id>\n"
    "${toolUseId == null ? "" : "<tool-use-id>$toolUseId</tool-use-id>\n"}"
    "<output-file>/tmp/task.output</output-file>\n<status>$status</status>\n"
    "<summary>Synthetic task finished</summary>\n<note>Synthetic note</note>\n"
    "<result>$result</result>\n<usage><total_tokens>1</total_tokens></usage>\n</task-notification>";

void main() {
  late Directory temp;
  late ClaudeEventDispatcher live;
  late ClaudeTranscriptCatalogRepository transcripts;
  const history = ClaudeHistoryMapper(content: ClaudeContentMapper());

  setUp(() {
    temp = Directory.systemTemp.createTempSync("claude-task-notification-");
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

  /// The one Automation row the last frame produces, identical live and after replay.
  Future<PluginMessageWithParts> automation({required List<Map<String, Object?>> frames}) async {
    final events = mapLive(frames: frames);
    final liveInfo = events.whereType<BridgeSseMessageUpdated>().single.info as PluginMessageAssistant;
    final liveParts = events.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part).toList();
    final stored = (await replay(records: frames)).where((message) => message.info.id == "notification").single;
    expect(liveInfo.sender, PluginMessageSender.system);
    expect(liveInfo.id, "notification");
    expect(liveInfo.agent, isNull);
    expect(liveInfo.modelID, isNull);
    expect(liveInfo.toJson(), stored.info.toJson());
    expect(liveParts, stored.parts);
    return stored;
  }

  test("a known task still folds into its tile, live and after replay", () async {
    final frames = [
      _assistant(toolUseId: "toolu-agent", name: "Agent"),
      _launchResult(toolUseId: "toolu-agent"),
      _user(
        uuid: "notification",
        content: _envelope(toolUseId: "toolu-agent"),
        origin: _origin,
      ),
    ];
    final events = mapLive(frames: frames);
    expect(events.whereType<BridgeSseMessageUpdated>(), isEmpty);
    final subtask = events.whereType<BridgeSseMessagePartUpdated>().single.part as PluginMessagePartSubtask;
    expect(subtask.taskState?.status, PluginToolStatus.completed);
    expect(subtask.taskState?.output, "Synthetic result");

    final stored = await replay(records: frames);
    expect(stored, hasLength(1));
    final replayed = stored.single.parts.single as PluginMessagePartSubtask;
    expect(replayed.taskState?.status, PluginToolStatus.completed);
    expect(replayed.taskState?.output, "Synthetic result");
  });

  test("a SendMessage-resumed agent's notification becomes one Automation step", () async {
    final stored = await automation(
      frames: [
        _assistant(toolUseId: "toolu-send", name: "SendMessage"),
        _user(
          uuid: "notification",
          content: _envelope(toolUseId: "toolu-send"),
          origin: _origin,
        ),
      ],
    );
    final step = stored.parts.single as PluginMessagePartTool;
    expect(step.tool, "Synthetic task finished");
    expect(step.kind, PluginToolKind.other);
    expect(step.state.status, PluginToolStatus.completed);
    expect(step.state.title, isNull);
    expect(step.state.output, "Synthetic result");
    expect(step.state.error, isNull);
    expect(step.id, isNot("toolu-send"));
  });

  test("a failed task carries its summary as the error", () async {
    final stored = await automation(
      frames: [
        _user(
          uuid: "notification",
          content: _envelope(toolUseId: "toolu-x", status: "failed"),
          origin: _origin,
        ),
      ],
    );
    final step = stored.parts.single as PluginMessagePartTool;
    expect(step.state.status, PluginToolStatus.error);
    expect(step.state.error, "Synthetic task finished");
  });

  test("an envelope without a tool-use id becomes an Automation step", () async {
    final stored = await automation(
      frames: [_user(uuid: "notification", content: _envelope(toolUseId: null), origin: _origin)],
    );
    expect((stored.parts.single as PluginMessagePartTool).tool, "Synthetic task finished");
  });

  test("an unparseable envelope becomes Automation text", () async {
    const text = "<task-notification>\n<summary>No task id</summary>\n</task-notification>";
    final stored = await automation(
      frames: [_user(uuid: "notification", content: text, origin: _origin)],
    );
    expect(stored.parts.single.text, text);
  });

  test("an older CLI's envelope without origin is still detected", () async {
    final stored = await automation(
      frames: [
        _user(
          uuid: "notification",
          content: _envelope(toolUseId: "toolu-unknown"),
          origin: null,
        ),
      ],
    );
    expect(stored.parts.single, isA<PluginMessagePartTool>());
  });

  test("a human prompt that quotes an envelope stays a user message", () async {
    final frame = _user(
      uuid: "notification",
      content: "Explain ${_envelope(toolUseId: "toolu-x")}",
      origin: null,
    );
    final events = mapLive(frames: [frame]);
    expect(events.whereType<BridgeSseMessageUpdated>().single.info, isA<PluginMessageUser>());
    expect((await replay(records: [frame])).single.info, isA<PluginMessageUser>());
  });
}

Map<String, Object?> _assistant({required String toolUseId, required String name}) => {
  "type": "assistant",
  "session_id": _sessionId,
  "sessionId": _sessionId,
  "uuid": "assistant-$toolUseId",
  "timestamp": _timestamp,
  "message": {
    "id": "msg-$toolUseId",
    "model": "claude-opus-5",
    "content": [
      {
        "type": "tool_use",
        "id": toolUseId,
        "name": name,
        "input": {"description": "Synthetic", "prompt": "Synthetic prompt", "subagent_type": "general-purpose"},
      },
    ],
  },
};

/// The async launch acknowledgement, carrying its typed result under both the
/// stream's and the transcript's key.
Map<String, Object?> _launchResult({required String toolUseId}) {
  const launched = {"isAsync": true, "status": "async_launched", "agentId": "task-1"};
  return {
    "type": "user",
    "session_id": _sessionId,
    "sessionId": _sessionId,
    "uuid": "launch-$toolUseId",
    "timestamp": _timestamp,
    "message": {
      "role": "user",
      "content": [
        {"type": "tool_result", "tool_use_id": toolUseId, "content": "Async agent launched."},
      ],
    },
    "tool_use_result": launched,
    "toolUseResult": launched,
  };
}

Map<String, Object?> _user({required String uuid, required String content, required Object? origin}) => {
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
