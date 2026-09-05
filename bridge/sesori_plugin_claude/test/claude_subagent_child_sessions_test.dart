import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

const _root = "11111111-2222-4333-8444-555555555555";
const _agentId = "abea3c20f79258c96";
const _child = "agent-$_agentId";
const _toolUseId = "toolu-agent";

void main() {
  group("ClaudeSubagentSessionId", () {
    test("owns the agent- id rule", () {
      expect(ClaudeSubagentSessionId.fromAgentId(_agentId), _child);
      expect(ClaudeSubagentSessionId.agentIdOf(_child), _agentId);
      expect(ClaudeSubagentSessionId.agentIdOf(_root), isNull);
      expect(ClaudeSubagentSessionId.agentIdOf("agent-"), isNull);
    });
  });

  group("ClaudeTranscriptCatalogRepository children", () {
    late Directory temp;
    late ClaudeTranscriptCatalogRepository catalog;
    late ClaudeTranscriptApi api;

    setUp(() {
      temp = Directory.systemTemp.createTempSync("claude-children-");
      api = ClaudeTranscriptApi(environment: {"CLAUDE_CONFIG_DIR": temp.path});
      catalog = ClaudeTranscriptCatalogRepository(transcriptApi: api);
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test("lists sub-agent transcripts under their root and excludes orphans and the legacy layout", () {
      _writeRoot(temp);
      _writeChild(temp, root: _root, agentId: _agentId, description: "Say hi");
      _writeChild(temp, root: "99999999-8888-4777-8666-555555555555", agentId: "orphan", description: "no root");
      File(p.join(_project(temp), "agent-legacy-abc.jsonl")).writeAsStringSync("{}\n");

      final records = catalog.listSessionRecords();
      final child = records.singleWhere((record) => record.id == _child);

      expect(records.map((record) => record.id), unorderedEquals([_root, _child]));
      expect(child.parentId, _root);
      expect(child.cwd, "/workspace");
      expect(child.title, "Say hi");
      expect(child.updatedAt, isNotNull);
      expect(catalog.findSessionById(sessionId: _child)?.parentId, _root);
      expect(catalog.findSessionById(sessionId: "agent-orphan"), isNull, reason: "no root record to attribute to");
    });

    test("getSessions lists roots only while getChildSessions and listAllSessions include children", () async {
      _writeRoot(temp);
      _writeChild(temp, root: _root, agentId: _agentId, description: "Say hi");

      final roots = await catalog.getSessions(projectId: "/workspace", start: null, limit: null);
      final children = await catalog.getChildSessions(sessionId: _root);
      final all = await catalog.listAllSessions(knownDirectories: const {});

      expect(roots.map((session) => session.id), [_root]);
      expect(children.single.id, _child);
      expect(children.single.parentID, _root);
      expect(children.single.directory, "/workspace");
      expect(all.map((session) => session.id), unorderedEquals([_root, _child]));
    });

    test("deleting a root removes its subagents directory; deleting a child removes its meta", () {
      _writeRoot(temp);
      _writeChild(temp, root: _root, agentId: _agentId, description: "Say hi");
      _writeChild(temp, root: _root, agentId: "second", description: "Other");
      final metaPath = ClaudeTranscriptApi.subagentMetaPath(transcriptPath: _childPath(temp, _root, "second"));

      expect(catalog.deleteSession(sessionId: "agent-second"), isTrue);
      expect(File(metaPath).existsSync(), isFalse);
      expect(catalog.findTranscriptPath(sessionId: _child), isNotNull);

      expect(catalog.deleteSession(sessionId: _root), isTrue);
      expect(Directory(p.join(_project(temp), _root)).existsSync(), isFalse);
      expect(catalog.listSessionRecords(), isEmpty);
    });

    test("child mode replays only the sub-agent's own records", () {
      _writeRoot(temp);
      _writeChild(temp, root: _root, agentId: _agentId, description: "Say hi");
      final records = catalog.readTranscriptRecords(sessionId: _child);

      final messages = const ClaudeHistoryMapper(content: ClaudeContentMapper()).map(
        sessionId: _child,
        agentId: _agentId,
        records: records,
        residentTaskToolUseIds: const {},
        catalogModelId: null,
      );

      expect(messages.map((message) => message.info.runtimeType.toString()), [
        "PluginMessageUser",
        "PluginMessageAssistant",
      ]);
      expect(messages.first.parts.single.text, "Reply with hi");
      expect(messages.last.parts.single.text, "hi");
      expect(messages, everyElement(predicate<PluginMessageWithParts>((m) => m.info.sessionID == _child)));
    });
  });

  group("ClaudeEventDispatcher child sessions", () {
    late ClaudeEventDispatcher dispatcher;

    setUp(() {
      dispatcher = ClaudeEventDispatcher(
        content: const ClaudeContentMapper(),
        tools: ClaudeToolTracker(),
        catalogModelId: ({required apiModel}) => null,
      );
      dispatcher.beginTurn(sessionId: _root, directory: "/workspace", model: null, variant: null);
    });

    test("announces the child once and follows repeated running and terminal transitions", () {
      dispatcher.map(message: ClaudeStreamMessage.parse(_agentAssistantFrame()));
      final launched = dispatcher.map(message: ClaudeStreamMessage.parse(_launchResultFrame()));

      expect(launched.map((event) => event.runtimeType), [
        BridgeSseSessionCreated,
        BridgeSseSessionStatus,
        BridgeSseMessagePartUpdated,
      ]);
      final created = (launched[0] as BridgeSseSessionCreated).info;
      expect(created["id"], _child);
      expect(created["parentID"], _root);
      expect(created["directory"], "/workspace");
      expect(created["title"], "Say hi");
      expect(
        (launched[1] as BridgeSseSessionStatus).status,
        isA<PluginSessionStatusBusy>(),
      );
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.busy()});
      expect(dispatcher.busyChildSessionIds(sessionId: _root), [_child]);

      dispatcher.completeTurn(sessionId: _root);
      final started = dispatcher.map(message: ClaudeStreamMessage.parse(_taskStartedFrame()));
      expect(started.map((event) => event.runtimeType), [BridgeSseMessagePartUpdated], reason: "already announced");

      final finished = dispatcher.map(message: ClaudeStreamMessage.parse(_taskNotificationFrame()));
      expect(finished.map((event) => event.runtimeType), [BridgeSseMessagePartUpdated, BridgeSseSessionStatus]);
      final idle = finished.last as BridgeSseSessionStatus;
      expect(idle.sessionID, _child);
      expect(idle.status, isA<PluginSessionStatusIdle>());
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.idle()});
      expect(dispatcher.busyChildSessionIds(sessionId: _root), isEmpty);

      final resumed = dispatcher.map(message: ClaudeStreamMessage.parse(_taskStartedFrame()));
      expect(resumed.map((event) => event.runtimeType), [BridgeSseSessionStatus, BridgeSseMessagePartUpdated]);
      expect(
        (resumed.first as BridgeSseSessionStatus).status,
        isA<PluginSessionStatusBusy>(),
      );
      final resumedPart = (resumed.last as BridgeSseMessagePartUpdated).part as PluginMessagePartSubtask;
      expect(resumedPart.taskState?.status, PluginToolStatus.running);
      expect(resumedPart.taskState?.output, isNull);
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.busy()});

      final finishedAgain = dispatcher.map(message: ClaudeStreamMessage.parse(_taskNotificationFrame()));
      expect(finishedAgain.map((event) => event.runtimeType), [BridgeSseMessagePartUpdated, BridgeSseSessionStatus]);
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.idle()});
    });

    test("routes forwarded sub-agent frames into the child session once its id is known", () {
      dispatcher.map(message: ClaudeStreamMessage.parse(_agentAssistantFrame()));
      final early = dispatcher.map(message: ClaudeStreamMessage.parse(_childTextFrame(text: "too early")));
      dispatcher.map(message: ClaudeStreamMessage.parse(_launchResultFrame()));
      dispatcher.completeTurn(sessionId: _root);

      final routed = dispatcher.map(message: ClaudeStreamMessage.parse(_childTextFrame(text: "hi")));

      expect(early, isEmpty, reason: "no child session exists before the sub-agent id is known");
      expect(routed.map((event) => event.runtimeType), [BridgeSseMessageUpdated, BridgeSseMessagePartUpdated]);
      expect(shared.Message.fromJson((routed[0] as BridgeSseMessageUpdated).info).sessionID, _child);
      final part = (routed[1] as BridgeSseMessagePartUpdated).part;
      expect(part.sessionID, _child);
      expect(part.text, "hi");
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.busy()});
    });

    test("a nested Agent call inside a child binds through the root's task frames and flattens under the root", () {
      dispatcher.map(message: ClaudeStreamMessage.parse(_agentAssistantFrame()));
      dispatcher.map(message: ClaudeStreamMessage.parse(_launchResultFrame()));
      dispatcher.map(
        message: ClaudeStreamMessage.parse({
          "type": "assistant",
          "session_id": _root,
          "parent_tool_use_id": _toolUseId,
          "message": {
            "id": "child-msg-2",
            "model": "claude-opus-5",
            "content": [
              {
                "type": "tool_use",
                "id": "toolu-nested",
                "name": "Agent",
                "input": {"description": "Nested", "prompt": "go deeper"},
              },
            ],
          },
        }),
      );

      final started = dispatcher.map(
        message: ClaudeStreamMessage.parse({
          "type": "system",
          "subtype": "task_started",
          "session_id": _root,
          "task_id": "nested-agent",
          "tool_use_id": "toolu-nested",
          "task_type": "local_agent",
        }),
      );

      expect(started.map((event) => event.runtimeType), [
        BridgeSseSessionCreated,
        BridgeSseSessionStatus,
        BridgeSseMessagePartUpdated,
      ]);
      final created = (started[0] as BridgeSseSessionCreated).info;
      expect(created["id"], "agent-nested-agent");
      expect(created["parentID"], _root, reason: "nested children are flattened under the root");
      expect(created["directory"], "/workspace");
      final part = (started[2] as BridgeSseMessagePartUpdated).part as PluginMessagePartSubtask;
      expect(part.sessionID, _child, reason: "the part renders in the session that made the call");
      expect(part.childSessionID, "agent-nested-agent");
      expect(dispatcher.busyChildSessionIds(sessionId: _root), unorderedEquals([_child, "agent-nested-agent"]));

      expect(dispatcher.cancelTasks(sessionId: _root).whereType<BridgeSseSessionStatus>(), hasLength(2));
    });

    test("cancelTasks idles the announced child and forgetSession drops it", () {
      dispatcher.map(message: ClaudeStreamMessage.parse(_agentAssistantFrame()));
      dispatcher.map(message: ClaudeStreamMessage.parse(_launchResultFrame()));
      dispatcher.completeTurn(sessionId: _root);

      final cancelled = dispatcher.cancelTasks(sessionId: _root);
      expect(cancelled.map((event) => event.runtimeType), [BridgeSseMessagePartUpdated, BridgeSseSessionStatus]);
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.idle()});

      dispatcher.forgetSession(sessionId: _root);
      expect(dispatcher.childSessionStatuses(), isEmpty);
    });

    test("forgetting a deleted child removes it from its root's statuses", () {
      dispatcher.map(message: ClaudeStreamMessage.parse(_agentAssistantFrame()));
      dispatcher.map(message: ClaudeStreamMessage.parse(_launchResultFrame()));

      dispatcher.forgetSession(sessionId: _child);

      expect(dispatcher.childSessionStatuses(), isEmpty);
      expect(dispatcher.busyChildSessionIds(sessionId: _root), isEmpty);
    });
  });
}

String _project(Directory temp) => p.join(temp.path, "projects", "-workspace");

String _childPath(Directory temp, String root, String agentId) =>
    p.join(_project(temp), root, "subagents", "agent-$agentId.jsonl");

void _writeRoot(Directory temp) {
  Directory(_project(temp)).createSync(recursive: true);
  File(p.join(_project(temp), "$_root.jsonl")).writeAsStringSync(
    [
      jsonEncode({
        "type": "user",
        "sessionId": _root,
        "uuid": "root-user",
        "cwd": "/workspace",
        "timestamp": "2026-09-01T10:00:00Z",
        "message": {"role": "user", "content": "launch an agent"},
      }),
    ].join("\n"),
  );
}

void _writeChild(Directory temp, {required String root, required String agentId, required String description}) {
  final path = _childPath(temp, root, agentId);
  File(path).createSync(recursive: true);
  File(path).writeAsStringSync(
    [
      jsonEncode({
        "type": "user",
        "isSidechain": true,
        "agentId": agentId,
        "sessionId": _root,
        "uuid": "child-user-$agentId",
        "cwd": "/workspace",
        "timestamp": "2026-09-01T10:00:01Z",
        "message": {"role": "user", "content": "Reply with hi"},
      }),
      jsonEncode({
        "type": "assistant",
        "isSidechain": true,
        "agentId": agentId,
        "sessionId": _root,
        "uuid": "child-assistant-$agentId",
        "cwd": "/workspace",
        "timestamp": "2026-09-01T10:00:02Z",
        "message": {
          "id": "child-msg-$agentId",
          "model": "claude-haiku-4-5",
          "content": [
            {"type": "text", "text": "hi"},
          ],
        },
      }),
    ].join("\n"),
  );
  File(ClaudeTranscriptApi.subagentMetaPath(transcriptPath: path)).writeAsStringSync(
    jsonEncode({"agentType": "general-purpose", "description": description, "toolUseId": _toolUseId, "spawnDepth": 1}),
  );
}

Map<String, Object?> _agentAssistantFrame() => {
  "type": "assistant",
  "session_id": _root,
  "message": {
    "id": "msg-1",
    "model": "claude-opus-5",
    "content": [
      {
        "type": "tool_use",
        "id": _toolUseId,
        "name": "Agent",
        "input": {"description": "Say hi", "prompt": "Reply with hi", "subagent_type": "general-purpose"},
      },
    ],
  },
};

Map<String, Object?> _launchResultFrame() => {
  "type": "user",
  "session_id": _root,
  "uuid": "launch-result",
  "message": {
    "role": "user",
    "content": [
      {"type": "tool_result", "tool_use_id": _toolUseId, "content": "Async agent launched successfully."},
    ],
  },
  "tool_use_result": {"isAsync": true, "status": "async_launched", "agentId": _agentId},
};

Map<String, Object?> _childTextFrame({required String text}) => {
  "type": "assistant",
  "session_id": _root,
  "parent_tool_use_id": _toolUseId,
  "message": {
    "id": "child-msg-1",
    "model": "claude-haiku-4-5",
    "content": [
      {"type": "text", "text": text},
    ],
  },
};

Map<String, Object?> _taskStartedFrame() => {
  "type": "system",
  "subtype": "task_started",
  "session_id": _root,
  "task_id": _agentId,
  "tool_use_id": _toolUseId,
  "task_type": "local_agent",
};

Map<String, Object?> _taskNotificationFrame() => {
  "type": "system",
  "subtype": "task_notification",
  "session_id": _root,
  "task_id": _agentId,
  "tool_use_id": _toolUseId,
  "status": "completed",
  "summary": "hi",
};
