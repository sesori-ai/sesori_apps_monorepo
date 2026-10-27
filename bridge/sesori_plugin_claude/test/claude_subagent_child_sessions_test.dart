import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
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
      final started = dispatcher.map(message: ClaudeStreamMessage.parse(_taskStartedFrame(toolUseId: _toolUseId)));
      expect(started.map((event) => event.runtimeType), [BridgeSseMessagePartUpdated], reason: "already announced");

      final finished = dispatcher.map(
        message: ClaudeStreamMessage.parse(_taskNotificationFrame(toolUseId: _toolUseId)),
      );
      expect(finished.map((event) => event.runtimeType), [BridgeSseMessagePartUpdated, BridgeSseSessionStatus]);
      final idle = finished.last as BridgeSseSessionStatus;
      expect(idle.sessionID, _child);
      expect(idle.status, isA<PluginSessionStatusIdle>());
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.idle()});
      expect(dispatcher.busyChildSessionIds(sessionId: _root), isEmpty);

      final resumed = dispatcher.map(message: ClaudeStreamMessage.parse(_taskStartedFrame(toolUseId: _toolUseId)));
      expect(resumed.map((event) => event.runtimeType), [BridgeSseSessionStatus, BridgeSseMessagePartUpdated]);
      expect(
        (resumed.first as BridgeSseSessionStatus).status,
        isA<PluginSessionStatusBusy>(),
      );
      final resumedPart = (resumed.last as BridgeSseMessagePartUpdated).part as PluginMessagePartSubtask;
      expect(resumedPart.taskState?.status, PluginToolStatus.running);
      expect(resumedPart.taskState?.output, isNull);
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.busy()});

      final finishedAgain = dispatcher.map(
        message: ClaudeStreamMessage.parse(_taskNotificationFrame(toolUseId: _toolUseId)),
      );
      expect(finishedAgain.map((event) => event.runtimeType), [BridgeSseMessagePartUpdated, BridgeSseSessionStatus]);
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.idle()});
    });

    test("a SendMessage resume, whose task frames name the SendMessage call, keeps the child busy until it ends", () {
      // Claude Code 2.1.310 registers a SendMessage-resumed agent under the
      // SendMessage call, so its task frames carry that tool-use id.
      const sendToolUseId = "toolu-send";
      dispatcher.map(message: ClaudeStreamMessage.parse(_agentAssistantFrame()));
      dispatcher.map(message: ClaudeStreamMessage.parse(_launchResultFrame()));
      dispatcher.completeTurn(sessionId: _root);
      dispatcher.map(message: ClaudeStreamMessage.parse(_taskNotificationFrame(toolUseId: _toolUseId)));
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.idle()});

      final resumed = dispatcher.map(message: ClaudeStreamMessage.parse(_taskStartedFrame(toolUseId: sendToolUseId)));

      expect(resumed.map((event) => event.runtimeType), [BridgeSseSessionStatus, BridgeSseMessagePartUpdated]);
      final busy = resumed.first as BridgeSseSessionStatus;
      expect(busy.sessionID, _child);
      expect(busy.status, isA<PluginSessionStatusBusy>());
      final reopened = (resumed.last as BridgeSseMessagePartUpdated).part as PluginMessagePartSubtask;
      expect(reopened.id, _toolUseId, reason: "the resume reopens the launching call's tile");
      expect(reopened.taskState?.status, PluginToolStatus.running);
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.busy()});
      expect(dispatcher.busyChildSessionIds(sessionId: _root), [_child]);

      final finished = dispatcher.map(
        message: ClaudeStreamMessage.parse(_taskNotificationFrame(toolUseId: sendToolUseId)),
      );

      expect(finished.map((event) => event.runtimeType), [BridgeSseMessagePartUpdated, BridgeSseSessionStatus]);
      expect((finished.first as BridgeSseMessagePartUpdated).part.id, _toolUseId);
      expect((finished.last as BridgeSseSessionStatus).status, isA<PluginSessionStatusIdle>());
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.idle()});

      // The wake-up envelope names the SendMessage call too. It stays its own
      // Automation row, as on replay, instead of rewriting the tile.
      final envelope = dispatcher.map(message: ClaudeStreamMessage.parse(_envelopeFrame(toolUseId: sendToolUseId)));
      expect(envelope.whereType<BridgeSseMessageUpdated>(), hasLength(1));
      expect(
        envelope.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part.id),
        isNot(contains(_toolUseId)),
      );
      expect(envelope.whereType<BridgeSseSessionStatus>(), isEmpty);
    });

    test("a sub-agent resumed after its process exited runs as its child, leaving the old tile alone", () {
      const sendToolUseId = "toolu-send";
      dispatcher.map(message: ClaudeStreamMessage.parse(_agentAssistantFrame()));
      dispatcher.map(message: ClaudeStreamMessage.parse(_launchResultFrame()));
      dispatcher.map(message: ClaudeStreamMessage.parse(_taskNotificationFrame(toolUseId: _toolUseId)));
      // The process exits (idle shutdown, stop, respawn) and drops its tasks;
      // the next turn runs in a new process that resumes the agent.
      dispatcher.cancelTasks(sessionId: _root);
      dispatcher.beginTurn(sessionId: _root, directory: "/workspace", model: null, variant: null);

      final resumed = dispatcher.map(message: ClaudeStreamMessage.parse(_taskStartedFrame(toolUseId: sendToolUseId)));

      expect(resumed.map((event) => event.runtimeType), [BridgeSseSessionStatus], reason: "no tile, no re-announce");
      expect((resumed.single as BridgeSseSessionStatus).sessionID, _child);
      expect((resumed.single as BridgeSseSessionStatus).status, isA<PluginSessionStatusBusy>());
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.busy()});
      expect(dispatcher.busyChildSessionIds(sessionId: _root), [_child]);
      expect(dispatcher.residentTaskToolUseIds(sessionId: _root), isEmpty, reason: "replay keeps the old tile too");

      final finished = dispatcher.map(
        message: ClaudeStreamMessage.parse(_taskNotificationFrame(toolUseId: sendToolUseId)),
      );
      expect(finished.map((event) => event.runtimeType), [BridgeSseSessionStatus]);
      expect((finished.single as BridgeSseSessionStatus).status, isA<PluginSessionStatusIdle>());
      expect(dispatcher.busyChildSessionIds(sessionId: _root), isEmpty);

      final envelope = dispatcher.map(message: ClaudeStreamMessage.parse(_envelopeFrame(toolUseId: sendToolUseId)));
      expect(envelope.whereType<BridgeSseMessageUpdated>(), hasLength(1), reason: "its own Automation step");
      expect(envelope.whereType<BridgeSseSessionStatus>(), isEmpty);

      // A resumed run still running when its process exits ends with it.
      dispatcher.map(message: ClaudeStreamMessage.parse(_taskStartedFrame(toolUseId: sendToolUseId)));
      final cancelled = dispatcher.cancelTasks(sessionId: _root);
      expect(cancelled.map((event) => event.runtimeType), [BridgeSseSessionStatus]);
      expect((cancelled.single as BridgeSseSessionStatus).status, isA<PluginSessionStatusIdle>());
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.idle()});
    });

    test("after a bridge restart a resumed sub-agent re-announces its child with its own title", () {
      final resumed = dispatcher.map(message: ClaudeStreamMessage.parse(_taskStartedFrame(toolUseId: "toolu-send")));

      expect(resumed.map((event) => event.runtimeType), [BridgeSseSessionCreated, BridgeSseSessionStatus]);
      final created = (resumed.first as BridgeSseSessionCreated).info;
      expect(created["id"], _child);
      expect(created["parentID"], _root);
      // The bridge rewrites a known child's catalog title from `created`.
      expect(created["title"], "Say hi");
      expect(dispatcher.childSessionStatuses(), {_child: const PluginSessionStatus.busy()});
    });

    test("routes forwarded sub-agent frames into the child session once its id is known", () {
      dispatcher.map(message: ClaudeStreamMessage.parse(_agentAssistantFrame()));
      final early = dispatcher.map(message: ClaudeStreamMessage.parse(_childTextFrame(text: "too early")));
      dispatcher.map(message: ClaudeStreamMessage.parse(_launchResultFrame()));
      dispatcher.completeTurn(sessionId: _root);

      final routed = dispatcher.map(message: ClaudeStreamMessage.parse(_childTextFrame(text: "hi")));

      expect(early, isEmpty, reason: "no child session exists before the sub-agent id is known");
      expect(routed.map((event) => event.runtimeType), [BridgeSseMessageUpdated, BridgeSseMessagePartUpdated]);
      expect((routed[0] as BridgeSseMessageUpdated).info.sessionID, _child);
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

Map<String, Object?> _taskStartedFrame({required String toolUseId}) => {
  "type": "system",
  "subtype": "task_started",
  "session_id": _root,
  "task_id": _agentId,
  "tool_use_id": toolUseId,
  "description": "Say hi",
  "task_type": "local_agent",
};

/// The `<task-notification>` wake-up that delivers a run's result.
Map<String, Object?> _envelopeFrame({required String toolUseId}) => {
  "type": "user",
  "session_id": _root,
  "uuid": "resumed-notification",
  "origin": {"kind": "task-notification"},
  "message": {
    "role": "user",
    "content":
        "<task-notification>\n<task-id>$_agentId</task-id>\n<tool-use-id>$toolUseId</tool-use-id>\n"
        "<status>completed</status>\n<summary>Agent finished</summary>\n<result>done</result>\n"
        "</task-notification>",
  },
};

Map<String, Object?> _taskNotificationFrame({required String toolUseId}) => {
  "type": "system",
  "subtype": "task_notification",
  "session_id": _root,
  "task_id": _agentId,
  "tool_use_id": toolUseId,
  "status": "completed",
  "summary": "hi",
};
