import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/repositories/codex_thread_repository.dart";
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
    final mapper = CodexEventMapper(pluginId: CodexPlugin.pluginId, projectCwd: projectCwd);
    final appServerApi = CodexAppServerApi(
      client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"),
    );
    final threadRepository = CodexThreadRepository(
      appServerApi: appServerApi,
    );

    List<BridgeSseEvent> mapThreadStarted(
      CodexEventMapper target,
      CodexServerNotification notification,
    ) {
      final dto = appServerApi.decodeThreadStartedParams(params: notification.params);
      final record = dto == null ? null : threadRepository.mapStartedNotification(dto: dto);
      return record == null ? const [] : target.mapThreadStarted(record);
    }

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
      final events = mapThreadStarted(
        mapper,
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
      final events = mapThreadStarted(
        mapper,
        const CodexServerNotification(
          method: "thread/started",
          params: {
            "thread": {"cwd": "/repo/app"},
          },
        ),
      );
      expect(events, isEmpty);
    });

    test("thread API decode recovery drops malformed DTO with an observable warning", () {
      late List<BridgeSseEvent> events;

      final output = _captureWarnings(() {
        events = mapThreadStarted(
          mapper,
          const CodexServerNotification(
            method: "thread/started",
            params: {
              "thread": {"id": "t-malformed", "createdAt": "not-a-number"},
            },
          ),
        );
      });

      expect(events, isEmpty);
      expect(output, contains("failed to decode thread/started notification"));
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
      final events = mapThreadStarted(
        mapper,
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
      final scopedMapper = CodexEventMapper(pluginId: CodexPlugin.pluginId, projectCwd: projectCwd)
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

    test("turn/started updates session time and emits busy status", () {
      final activityMapper = CodexEventMapper(
        pluginId: CodexPlugin.pluginId,
        projectCwd: projectCwd,
      );
      mapThreadStarted(
        activityMapper,
        const CodexServerNotification(
          method: "thread/started",
          params: {
            "thread": {
              "id": "t-activity",
              "cwd": projectCwd,
              "createdAt": 1779293088,
              "updatedAt": 1779293090,
            },
          },
        ),
      );

      final events = activityMapper.map(
        const CodexServerNotification(
          method: "turn/started",
          params: {
            "threadId": "t-activity",
            "turn": {"id": "u-1", "startedAt": 1779293100},
          },
        ),
      );

      expect(events, hasLength(2));
      final updated = events.whereType<BridgeSseSessionUpdated>().single;
      final session = shared.Session.fromJson(updated.info);
      expect(session.time?.created, 1779293088000);
      expect(session.time?.updated, 1779293100000);
      expect(updated.titleChanged, isFalse);
      expect(parseAsSesori(updated), isA<shared.SesoriSessionUpdated>());

      final status = events.whereType<BridgeSseSessionStatus>().single;
      expect(status.sessionID, "t-activity");
      expect(shared.SessionStatus.fromJson(status.status), isA<shared.SessionStatusBusy>());
      expect(parseAsSesori(status), isA<shared.SesoriSessionStatus>());
    });

    test("turn/completed updates session time and emits idle status", () {
      final activityMapper = CodexEventMapper(
        pluginId: CodexPlugin.pluginId,
        projectCwd: projectCwd,
      );
      mapThreadStarted(
        activityMapper,
        const CodexServerNotification(
          method: "thread/started",
          params: {
            "thread": {
              "id": "t-activity",
              "cwd": projectCwd,
              "createdAt": 1779293088,
              "updatedAt": 1779293090,
            },
          },
        ),
      );

      final events = activityMapper.map(
        const CodexServerNotification(
          method: "turn/completed",
          params: {
            "threadId": "t-activity",
            "turn": {"id": "u-1", "completedAt": 1779293110},
          },
        ),
      );
      expect(events, hasLength(2));
      final session = shared.Session.fromJson(
        events.whereType<BridgeSseSessionUpdated>().single.info,
      );
      expect(session.time?.created, 1779293088000);
      expect(session.time?.updated, 1779293110000);
      expect(events.whereType<BridgeSseSessionIdle>().single.sessionID, "t-activity");
    });

    test("thread/status/changed maps direct active and nested idle statuses", () {
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
            "status": {
              "status": {"type": "idle"},
            },
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
      final richMapper = CodexEventMapper(
        pluginId: CodexPlugin.pluginId,
        projectCwd: projectCwd,
        config: const CodexConfigDefaults(model: "gpt-5.5", modelProvider: "openai"),
      );
      // thread/started carries the provider; the mapper remembers it per thread.
      mapThreadStarted(
        richMapper,
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
      final richMapper = CodexEventMapper(
        pluginId: CodexPlugin.pluginId,
        projectCwd: projectCwd,
        config: const CodexConfigDefaults(model: "gpt-5.5", modelProvider: "openai"),
      );
      mapThreadStarted(
        richMapper,
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
              "command": "/bin/zsh -lc 'ls -la'",
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

    test("commandExecution treats a non-zero exit code as an error", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-1",
            "item": {
              "type": "commandExecution",
              "id": "i-failed",
              "command": "/bin/zsh -lc /usr/bin/false",
              "aggregatedOutput": "",
              "exitCode": 1,
              // Some app-server versions have reported `completed` here even
              // though the explicit process exit code is authoritative.
              "status": "completed",
            },
          },
        ),
      );

      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.state?.title, "/usr/bin/false");
      expect(part.state?.status, PluginToolStatus.error);
      expect(part.state?.error, "");
    });

    test("raw rollout output enriches and cannot be downgraded by a later item", () {
      final call = CodexRolloutLineDto.fromJson({
        "timestamp": "2026-07-23T08:00:00Z",
        "type": "response_item",
        "payload": {
          "type": "function_call",
          "id": "fc-failed",
          "call_id": "call-failed",
          "name": "exec_command",
          "arguments": '{"cmd":"/usr/bin/false"}',
        },
      });
      final output = CodexRolloutLineDto.fromJson({
        "timestamp": "2026-07-23T08:00:01Z",
        "type": "response_item",
        "payload": {
          "type": "function_call_output",
          "call_id": "call-failed",
          "output":
              "Chunk ID: failed\n"
              "Wall time: 0.01 seconds\n"
              "Process exited with code 1\n"
              "Final output:\n",
        },
      });

      final running = mapper.mapRolloutLine(threadId: "t-raw", line: call);
      final completed = mapper.mapRolloutLine(
        threadId: "t-raw",
        line: output,
      );
      final lateItem = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-raw",
            "item": {
              "type": "commandExecution",
              "id": "call-failed",
              "command": "/bin/zsh -lc /usr/bin/false",
              "aggregatedOutput": "",
              "exitCode": 1,
              "status": "failed",
            },
          },
        ),
      );

      expect(
        (running[1] as BridgeSseMessagePartUpdated).part.state?.title,
        "/usr/bin/false",
      );
      final rawPart = (completed[1] as BridgeSseMessagePartUpdated).part;
      final latePart = (lateItem[1] as BridgeSseMessagePartUpdated).part;
      expect(rawPart.state?.status, PluginToolStatus.error);
      expect(rawPart.state?.output, contains("Chunk ID: failed"));
      expect(latePart.state?.status, rawPart.state?.status);
      expect(latePart.state?.output, rawPart.state?.output);
      expect(latePart.state?.error, rawPart.state?.error);
      mapper.clearRolloutTurn(threadId: "t-raw");
    });

    test("a structured non-zero exit overrides an unclassified raw result", () {
      final call = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "function_call",
          "call_id": "call-structured-failure",
          "name": "exec_command",
          "arguments": '{"cmd":"/usr/bin/false"}',
        },
      });
      final output = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "function_call_output",
          "call_id": "call-structured-failure",
          "output": "opaque executor output",
        },
      });
      mapper
        ..mapRolloutLine(threadId: "t-structured", line: call)
        ..mapRolloutLine(threadId: "t-structured", line: output);

      final events = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-structured",
            "item": {
              "type": "commandExecution",
              "id": "call-structured-failure",
              "command": "/bin/zsh -lc /usr/bin/false",
              "aggregatedOutput": "",
              "exitCode": 1,
              "status": "completed",
            },
          },
        ),
      );

      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.state?.status, PluginToolStatus.error);
      expect(part.state?.output, "opaque executor output");
      expect(part.state?.error, "opaque executor output");
      mapper.clearRolloutTurn(threadId: "t-structured");
    });

    test("raw fallback titles clip non-BMP text by Unicode code point", () {
      final prefix = List<String>.filled(119, "a").join();
      final line = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "function_call",
          "call_id": "call-unicode",
          "name": "unknown_tool",
          "arguments": "$prefix😀trailing",
        },
      });

      final events = mapper.mapRolloutLine(
        threadId: "t-unicode",
        line: line,
      );

      final title = (events[1] as BridgeSseMessagePartUpdated).part.state?.title;
      expect(title, "$prefix😀");
      expect(title?.runes, hasLength(120));
      mapper.clearRolloutTurn(threadId: "t-unicode");
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

    test("dynamicToolCall streams a running tool and its completed output", () {
      final started = mapper.map(
        const CodexServerNotification(
          method: "item/started",
          params: {
            "threadId": "t-1",
            "item": {
              "type": "dynamicToolCall",
              "id": "i-wait",
              "tool": "wait",
              "namespace": "functions",
              "arguments": {
                "cell_id": "166",
                "yield_time_ms": 10000,
                "max_tokens": 20000,
              },
              "status": "inProgress",
              "contentItems": null,
              "durationMs": null,
              "success": null,
            },
          },
        ),
      );

      expect(started, hasLength(2));
      final runningPart = (started[1] as BridgeSseMessagePartUpdated).part;
      expect(runningPart.type, PluginMessagePartType.tool);
      expect(runningPart.id, "i-wait-tool");
      expect(runningPart.tool, "wait");
      expect(runningPart.state?.status, PluginToolStatus.running);
      expect(runningPart.state?.title, contains("cell_id: 166"));
      expect(runningPart.state?.title, contains("yield_time_ms: 10000"));
      expect(runningPart.state?.output, isNull);

      final completed = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-1",
            "item": {
              "type": "dynamicToolCall",
              "id": "i-wait",
              "tool": "wait",
              "namespace": "functions",
              "arguments": {
                "cell_id": "166",
                "yield_time_ms": 10000,
                "max_tokens": 20000,
              },
              "status": "completed",
              "contentItems": [
                {"type": "inputText", "text": "wait completed"},
              ],
              "durationMs": 2000,
              "success": true,
            },
          },
        ),
      );

      expect(completed, hasLength(2));
      final completedPart = (completed[1] as BridgeSseMessagePartUpdated).part;
      expect(completedPart.id, runningPart.id);
      expect(completedPart.state?.status, PluginToolStatus.completed);
      expect(completedPart.state?.output, "wait completed");
    });

    test("dynamicToolCall falls back for malformed or empty tool names", () {
      for (final rawTool in <Object?>[42, ""]) {
        final events = mapper.map(
          CodexServerNotification(
            method: "item/started",
            params: {
              "threadId": "t-1",
              "item": {
                "type": "dynamicToolCall",
                "id": "i-fallback",
                "tool": rawTool,
                "arguments": const <String, Object?>{},
                "status": "inProgress",
              },
            },
          ),
        );

        final part = (events[1] as BridgeSseMessagePartUpdated).part;
        expect(part.tool, "tool");
        expect(part.state?.status, PluginToolStatus.running);
      }
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
      final created = mapThreadStarted(
        mapper,
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

String _captureWarnings(void Function() action) {
  final previousLevel = Log.level;
  final stderr = _BufferingStdout();
  try {
    Log.level = LogLevel.warning;
    IOOverrides.runZoned(action, stderr: () => stderr);
  } finally {
    Log.level = previousLevel;
  }
  return stderr.text;
}

class _BufferingStdout implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
