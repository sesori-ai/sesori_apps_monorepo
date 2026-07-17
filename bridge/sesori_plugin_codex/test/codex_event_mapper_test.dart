import "package:codex_plugin/codex_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

/// These tests assert the mapper emits **sesori-schema** payloads — the maps
/// carried on session/message/status events must round-trip through the same
/// parsers the bridge core uses (`Session`/`Message`/`SessionStatus.fromJson`
/// and `SesoriSseEvent.fromJson`). The previous mapper passed codex's raw
/// JSON straight through, so every live event failed to parse on the bridge.
void main() {
  group("CodexEventMapper", () {
    const projectCwd = "/repo/app";
    final mapper = _ContextualMapper(
      pluginId: CodexPlugin.pluginId,
      projectCwd: projectCwd,
    );

    /// Replicates `BridgeEventMapper`'s payload construction and runs the
    /// bridge's `SesoriSseEvent.fromJson`. Throwing here is exactly the bug
    /// being guarded against — it means the mobile client drops the event.
    shared.SesoriSseEvent parseAsSesori(BridgeSseEvent event) {
      final payload = switch (event) {
        BridgeSseSessionCreated(:final info) => {"type": "session.created", "info": info},
        BridgeSseSessionUpdated(:final info) => {"type": "session.updated", "info": info},
        BridgeSseSessionDeleted(:final info) => {"type": "session.deleted", "info": info},
        BridgeSseSessionStatus(:final sessionID, :final status) => {
          "type": "session.status",
          "sessionID": sessionID,
          "status": status,
        },
        BridgeSseMessageUpdated(:final info) => {"type": "message.updated", "info": info},
        _ => throw ArgumentError("parseAsSesori: unhandled ${event.runtimeType}"),
      };
      return shared.SesoriSseEvent.fromJson(payload);
    }

    test("thread/started → SessionCreated parseable as Session", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "thread/started",
          params: {
            "thread": {
              "id": "t-1",
              "name": "Plan the theme",
              "cwd": "/repo/app",
              "createdAt": 1779293088,
              "updatedAt": 1779293090,
              "status": {"type": "idle"},
              "modelProvider": "openai",
              "cliVersion": "0.121.0",
              "source": "vscode",
            },
          },
        ),
      );

      expect(events, hasLength(1));
      final created = events.single as BridgeSseSessionCreated;
      final session = shared.Session.fromJson(created.info);
      expect(session.id, "t-1");
      expect(session.pluginId, CodexPlugin.pluginId);
      expect(session.projectID, projectCwd);
      expect(session.directory, "/repo/app");
      expect(session.title, "Plan the theme");
      expect(session.time?.created, 1779293088000);
      expect(session.time?.updated, 1779293090000);
      expect(parseAsSesori(created), isA<shared.SesoriSessionCreated>());
    });

    test("thread/started without an id is dropped", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "thread/started",
          params: {
            "thread": {"cwd": "/repo/app"},
          },
        ),
      );
      expect(events, isEmpty);
    });

    test("thread/name/updated → SessionUpdated parseable as Session", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "thread/name/updated",
          params: {"threadId": "t-1", "threadName": "Welcome session"},
        ),
      );

      expect(events, hasLength(1));
      final updated = events.single as BridgeSseSessionUpdated;
      expect(updated.titleChanged, isTrue);
      final session = shared.Session.fromJson(updated.info);
      expect(session.id, "t-1");
      expect(session.pluginId, CodexPlugin.pluginId);
      expect(session.title, "Welcome session");
      expect(session.projectID, projectCwd);
      expect(parseAsSesori(updated), isA<shared.SesoriSessionUpdated>());
    });

    test("thread/started for a non-launch cwd emits that cwd's derived project id", () {
      // The bridge derives one project per cwd, so a session started outside the
      // launch dir must carry its own cwd as the project id — otherwise the
      // mobile session list (opened on the derived project) drops it as a
      // project mismatch.
      final events = mapper.map(
        const CodexServerNotification(
          method: "thread/started",
          params: {
            "thread": {"id": "t-2", "name": "Sub", "cwd": "/repo/app/packages/core"},
          },
        ),
      );

      final session = shared.Session.fromJson((events.single as BridgeSseSessionCreated).info);
      expect(session.projectID, "/repo/app/packages/core");
      expect(session.directory, "/repo/app/packages/core");
    });

    test("thread/name/updated uses the plugin-fed directory for its project id", () {
      // A thread/name/updated notification carries no cwd, so the mapper relies
      // on the directory the plugin learned when the thread was started/resumed.
      final scopedMapper = _ContextualMapper(pluginId: CodexPlugin.pluginId, projectCwd: projectCwd)
        ..setThreadDirectory("t-9", "/repo/app/packages/ui");

      final events = scopedMapper.map(
        const CodexServerNotification(
          method: "thread/name/updated",
          params: {"threadId": "t-9", "threadName": "Renamed"},
        ),
      );

      final session = shared.Session.fromJson((events.single as BridgeSseSessionUpdated).info);
      expect(session.projectID, "/repo/app/packages/ui");
    });

    test("turn/started → SessionStatus(busy) parseable as SessionStatus", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "turn/started",
          params: {
            "threadId": "t-1",
            "turn": {"id": "u-1"},
          },
        ),
      );

      expect(events, hasLength(1));
      final status = events.single as BridgeSseSessionStatus;
      expect(status.sessionID, "t-1");
      expect(shared.SessionStatus.fromJson(status.status), isA<shared.SessionStatusBusy>());
      expect(parseAsSesori(status), isA<shared.SesoriSessionStatus>());
    });

    test("turn/completed → SessionIdle", () {
      final events = mapper.map(
        const CodexServerNotification(method: "turn/completed", params: {"threadId": "t-1"}),
      );
      expect(events, hasLength(1));
      expect((events.single as BridgeSseSessionIdle).sessionID, "t-1");
    });

    test("thread/status/changed maps active→busy and idle→idle", () {
      final active = mapper.map(
        const CodexServerNotification(
          method: "thread/status/changed",
          params: {
            "threadId": "t-1",
            "status": {"type": "active", "activeFlags": <Object?>[]},
          },
        ),
      );
      final idle = mapper.map(
        const CodexServerNotification(
          method: "thread/status/changed",
          params: {
            "threadId": "t-1",
            "status": {"type": "idle"},
          },
        ),
      );

      expect(
        shared.SessionStatus.fromJson((active.single as BridgeSseSessionStatus).status),
        isA<shared.SessionStatusBusy>(),
      );
      expect(
        shared.SessionStatus.fromJson((idle.single as BridgeSseSessionStatus).status),
        isA<shared.SessionStatusIdle>(),
      );
    });

    test("item userMessage → MessageUpdated + MessagePartUpdated", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-1",
            "turnId": "u-1",
            "item": {
              "type": "userMessage",
              "id": "i-user",
              "content": [
                {"type": "text", "text": "hey", "text_elements": <Object?>[]},
              ],
            },
          },
        ),
      );

      expect(events, hasLength(2));
      final message = events[0] as BridgeSseMessageUpdated;
      final parsed = shared.Message.fromJson(message.info);
      expect(parsed, isA<shared.MessageUser>());
      expect(parsed.id, "i-user");
      expect(parsed.sessionID, "t-1");
      expect(parseAsSesori(message), isA<shared.SesoriMessageUpdated>());

      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.type, PluginMessagePartType.text);
      expect(part.messageID, "i-user");
      expect(part.id, "i-user-text");
      expect(part.text, "hey");
    });

    test("item agentMessage → assistant message + text part", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-1",
            "turnId": "u-1",
            "item": {
              "type": "agentMessage",
              "id": "i-agent",
              "text": "Hi. What do you need changed?",
              "phase": "final_answer",
            },
          },
        ),
      );

      expect(events, hasLength(2));
      expect(shared.Message.fromJson((events[0] as BridgeSseMessageUpdated).info), isA<shared.MessageAssistant>());
      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.type, PluginMessagePartType.text);
      expect(part.text, "Hi. What do you need changed?");
    });

    test("agentMessage falls back to config model when no per-thread model set", () {
      final richMapper = _ContextualMapper(
        pluginId: CodexPlugin.pluginId,
        projectCwd: projectCwd,
        config: const CodexConfigDefaults(model: "gpt-5.5", modelProvider: "openai"),
      );
      // thread/started carries the provider; the mapper remembers it per thread.
      richMapper.map(
        const CodexServerNotification(
          method: "thread/started",
          params: {
            "thread": {"id": "t-9", "modelProvider": "openai"},
          },
        ),
      );

      final events = richMapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-9",
            "item": {"type": "agentMessage", "id": "i-1", "text": "hello"},
          },
        ),
      );

      final message = shared.Message.fromJson(
        (events[0] as BridgeSseMessageUpdated).info,
      );
      expect(message, isA<shared.MessageAssistant>());
      final assistant = message as shared.MessageAssistant;
      expect(assistant.agent, equals("codex"));
      expect(assistant.providerID, equals("openai"));
      expect(assistant.modelID, equals("gpt-5.5"));
    });

    test("agentMessage uses the per-thread model the plugin recorded", () {
      final richMapper = _ContextualMapper(
        pluginId: CodexPlugin.pluginId,
        projectCwd: projectCwd,
        config: const CodexConfigDefaults(model: "gpt-5.5", modelProvider: "openai"),
      );
      richMapper.map(
        const CodexServerNotification(
          method: "thread/started",
          params: {
            "thread": {"id": "t-9", "modelProvider": "openai"},
          },
        ),
      );
      // The plugin records the model codex actually resolved for the thread
      // (e.g. the user picked gpt-5.4-mini over the gpt-5.5 config default).
      richMapper.setThreadModel("t-9", "gpt-5.4-mini");

      final events = richMapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-9",
            "item": {"type": "agentMessage", "id": "i-1", "text": "hello"},
          },
        ),
      );
      final assistant =
          shared.Message.fromJson(
                (events[0] as BridgeSseMessageUpdated).info,
              )
              as shared.MessageAssistant;
      expect(assistant.modelID, equals("gpt-5.4-mini"));
      expect(assistant.providerID, equals("openai"));

      // Clearing the override falls back to the config default again.
      richMapper.setThreadModel("t-9", null);
      final events2 = richMapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-9",
            "item": {"type": "agentMessage", "id": "i-2", "text": "again"},
          },
        ),
      );
      final assistant2 =
          shared.Message.fromJson(
                (events2[0] as BridgeSseMessageUpdated).info,
              )
              as shared.MessageAssistant;
      expect(assistant2.modelID, equals("gpt-5.5"));
    });

    test("item reasoning → assistant message + reasoning part", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-1",
            "turnId": "u-1",
            "item": {
              "type": "reasoning",
              "id": "i-reason",
              "summary": ["Thinking about it"],
              "content": <Object?>[],
            },
          },
        ),
      );

      expect(events, hasLength(2));
      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.type, PluginMessagePartType.reasoning);
      expect(part.id, "i-reason-reasoning");
      expect(part.text, "Thinking about it");
    });

    test("commandExecution (completed) → assistant message + tool part", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-1",
            "item": {
              "type": "commandExecution",
              "id": "i-cmd",
              "command": "ls -la",
              "aggregatedOutput": "total 0\nfoo.dart",
              "exitCode": 0,
              "status": "completed",
            },
          },
        ),
      );

      expect(events, hasLength(2));
      expect(
        shared.Message.fromJson((events[0] as BridgeSseMessageUpdated).info),
        isA<shared.MessageAssistant>(),
      );
      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.type, PluginMessagePartType.tool);
      expect(part.id, "i-cmd-tool");
      expect(part.tool, "shell");
      expect(part.state?.status, PluginToolStatus.completed);
      expect(part.state?.title, "ls -la");
      expect(part.state?.output, contains("foo.dart"));
    });

    test("commandExecution (started/inProgress) → running tool part", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "item/started",
          params: {
            "threadId": "t-1",
            "item": {
              "type": "commandExecution",
              "id": "i-cmd",
              "command": "sleep 1",
              "status": "inProgress",
            },
          },
        ),
      );
      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.state?.status, PluginToolStatus.running);
      // Output is withheld until completion.
      expect(part.state?.output, isNull);
    });

    test("fileChange → edit tool part titled with the touched paths", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-1",
            "item": {
              "type": "fileChange",
              "id": "i-fc",
              "status": "completed",
              "changes": [
                {
                  "path": "lib/main.dart",
                  "kind": {"type": "update"},
                  "diff": "@@ -1 +1 @@\n-a\n+b",
                },
              ],
            },
          },
        ),
      );
      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.type, PluginMessagePartType.tool);
      expect(part.tool, "edit");
      expect(part.state?.title, "lib/main.dart");
      expect(part.state?.output, contains("+b"));
    });

    test("mcpToolCall (failed) → error tool part", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-1",
            "item": {
              "type": "mcpToolCall",
              "id": "i-mcp",
              "server": "playwright",
              "tool": "click",
              "status": "failed",
              "error": {"message": "element not found"},
            },
          },
        ),
      );
      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.type, PluginMessagePartType.tool);
      expect(part.tool, "click");
      expect(part.state?.status, PluginToolStatus.error);
      expect(part.state?.title, "playwright/click");
      expect(part.state?.error, "element not found");
    });

    test("genuinely unrenderable item kinds (todoList) are still dropped", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "item/started",
          params: {
            "threadId": "t-1",
            "item": {"type": "todoList", "id": "i-todo"},
          },
        ),
      );
      expect(events, isEmpty);
    });

    test("item/agentMessage/delta → MessagePartDelta on the text part", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "item/agentMessage/delta",
          params: {"threadId": "t-1", "itemId": "i-1", "delta": "hello "},
        ),
      );
      expect(events, hasLength(1));
      final delta = events.single as BridgeSseMessagePartDelta;
      expect(delta.messageID, "i-1");
      expect(delta.partID, "i-1-text");
      expect(delta.delta, "hello ");
    });

    test("error → SessionError", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "error",
          params: {
            "threadId": "t-1",
            "error": {"message": "boom"},
          },
        ),
      );
      expect(events, hasLength(1));
      expect((events.single as BridgeSseSessionError).sessionID, "t-1");
    });

    test("notifications with no bridge analog are dropped", () {
      for (final method in const [
        "account/rateLimits/updated",
        "thread/closed",
        "thread/tokenUsage/updated",
        "item/commandExecution/outputDelta",
      ]) {
        expect(
          mapper.map(CodexServerNotification(method: method, params: const {})),
          isEmpty,
          reason: "$method should be dropped",
        );
      }
    });

    test("regression: real bug-log payloads parse cleanly", () {
      // The exact thread/started payload from the bug report.
      final created = mapper.map(
        const CodexServerNotification(
          method: "thread/started",
          params: {
            "thread": {
              "id": "019e4621-e3d6-7213-acde-f23b8d02fb7e",
              "forkedFromId": null,
              "preview": "",
              "ephemeral": false,
              "modelProvider": "openai",
              "createdAt": 1779293088,
              "updatedAt": 1779293088,
              "status": {"type": "idle"},
              "path": "/Users/x/.codex/sessions/2026/05/20/rollout.jsonl",
              "cwd": "/repo/app",
              "cliVersion": "0.121.0",
              "source": "vscode",
              "agentNickname": null,
              "agentRole": null,
              "gitInfo": null,
              "name": null,
              "turns": <Object?>[],
            },
          },
        ),
      );
      expect(() => parseAsSesori(created.single), returnsNormally);

      // The exact agentMessage item payload from the bug report.
      final agent = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "019e4621-e3d6-7213-acde-f23b8d02fb7e",
            "turnId": "019e4621-e9ea-7841-9ca0-9d787c4dcc3b",
            "item": {
              "type": "agentMessage",
              "id": "msg_00b7dd45419ee7cb016a0ddbad6be481919f4a7dd4265c2287",
              "text": "Hi. What do you need changed?",
              "phase": "final_answer",
              "memoryCitation": null,
            },
          },
        ),
      );
      expect(() => parseAsSesori(agent[0]), returnsNormally);
    });
  });
}

class _ContextualMapper {
  _ContextualMapper({
    required String pluginId,
    required String projectCwd,
    CodexConfigDefaults config = const CodexConfigDefaults.empty(),
  }) : _tracker = CodexContextTracker(
         pluginId: pluginId,
         launchDirectory: projectCwd,
         defaults: config,
       ),
       _repository = CodexAppServerRepository(
         api: CodexAppServerApi(
           client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"),
         ),
       );

  final CodexEventMapper _mapper = const CodexEventMapper();
  final CodexContextTracker _tracker;
  final CodexAppServerRepository _repository;

  List<BridgeSseEvent> map(CodexServerNotification notification) {
    final event = _repository.mapNotification(
      CodexAppServerApi.parseNotification(notification),
    );
    final contextFacts = event.context;
    if (contextFacts != null) _tracker.recordFacts(contextFacts);
    return _mapper.map(
      event,
      context: _tracker.snapshot(
        threadId: event.threadId,
        notificationDirectory: contextFacts?.directory,
      ),
    );
  }

  void setThreadDirectory(String threadId, String? directory) {
    _tracker.record(
      threadId: threadId,
      model: null,
      provider: null,
      directory: directory,
    );
  }

  void setThreadModel(String threadId, String? model) {
    _tracker.setModel(threadId: threadId, model: model);
  }
}
