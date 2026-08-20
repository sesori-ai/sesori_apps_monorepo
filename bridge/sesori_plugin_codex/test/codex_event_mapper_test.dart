import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/models/codex_image_bearing_item_dto.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/api/parsers/codex_command_execution_parser.dart";
import "package:codex_plugin/src/api/parsers/codex_file_change_parser.dart";
import "package:codex_plugin/src/api/parsers/codex_image_bearing_item_parser.dart";
import "package:codex_plugin/src/repositories/codex_thread_repository.dart";
import "package:codex_plugin/src/repositories/codex_tool_lifecycle_tracker.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
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
    const imageAttachmentMapper = CodexImageAttachmentMapper();
    const imageBearingItemParser = CodexImageBearingItemParser();
    const rolloutToolMapper = CodexRolloutToolMapper(
      imageAttachmentMapper: imageAttachmentMapper,
    );
    final mapper = CodexEventMapper(
      pluginId: CodexPlugin.pluginId,
      projectCwd: projectCwd,
      imageAttachmentMapper: imageAttachmentMapper,
      imageBearingItemParser: imageBearingItemParser,
      rolloutToolMapper: rolloutToolMapper,
    );
    final rolloutLifecycle = _ToolLifecycleHarness(
      eventMapper: mapper,
      toolTracker: CodexToolLifecycleTracker(
        rolloutToolMapper: rolloutToolMapper,
      ),
    );
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
      final scopedMapper = CodexEventMapper(
        pluginId: CodexPlugin.pluginId,
        projectCwd: projectCwd,
        imageAttachmentMapper: imageAttachmentMapper,
        imageBearingItemParser: imageBearingItemParser,
        rolloutToolMapper: rolloutToolMapper,
      )..setThreadDirectory("t-9", "/repo/app/packages/ui");

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
        imageAttachmentMapper: imageAttachmentMapper,
        imageBearingItemParser: imageBearingItemParser,
        rolloutToolMapper: rolloutToolMapper,
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
        imageAttachmentMapper: imageAttachmentMapper,
        imageBearingItemParser: imageBearingItemParser,
        rolloutToolMapper: rolloutToolMapper,
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

    test("item userMessage carries the prompt id codex echoes as clientId", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-1",
            "turnId": "u-1",
            "item": {
              "type": "userMessage",
              "id": "i-user",
              "clientId": "prm_1",
              "content": [
                {"type": "text", "text": "hey", "text_elements": <Object?>[]},
              ],
            },
          },
        ),
      );

      final parsed = shared.Message.fromJson((events[0] as BridgeSseMessageUpdated).info);
      expect((parsed as shared.MessageUser).promptId, "prm_1");
    });

    test("item userMessage typed in the codex CLI stays unattributed", () {
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

      final parsed = shared.Message.fromJson((events[0] as BridgeSseMessageUpdated).info);
      expect((parsed as shared.MessageUser).promptId, isNull);
    });

    test("item lifecycle timestamps survive live message updates", () {
      const threadId = "t-timestamps";
      final userStarted = mapper.map(
        const CodexServerNotification(
          method: "item/started",
          params: {
            "threadId": threadId,
            "startedAtMs": 1779293100123,
            "item": {"type": "userMessage", "id": "i-user-time", "content": <Object?>[]},
          },
        ),
      );
      final userCompleted = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": threadId,
            "completedAtMs": 1779293100456,
            "item": {"type": "userMessage", "id": "i-user-time", "content": <Object?>[]},
          },
        ),
      );
      final assistantStarted = mapper.map(
        const CodexServerNotification(
          method: "item/started",
          params: {
            "threadId": threadId,
            "startedAtMs": 1779293101000,
            "item": {"type": "agentMessage", "id": "i-agent-time", "text": ""},
          },
        ),
      );
      final assistantCompleted = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": threadId,
            "completedAtMs": 1779293102000,
            "item": {"type": "agentMessage", "id": "i-agent-time", "text": "done"},
          },
        ),
      );

      final startedUser = shared.Message.fromJson((userStarted.first as BridgeSseMessageUpdated).info);
      final completedUser = shared.Message.fromJson((userCompleted.first as BridgeSseMessageUpdated).info);
      final startedAssistant = shared.Message.fromJson((assistantStarted.first as BridgeSseMessageUpdated).info);
      final completedAssistant = shared.Message.fromJson((assistantCompleted.first as BridgeSseMessageUpdated).info);
      expect(startedUser.time, const shared.MessageTime(created: 1779293100123, completed: null));
      expect(completedUser.time, startedUser.time);
      expect(startedAssistant.time, const shared.MessageTime(created: 1779293101000, completed: null));
      expect(
        completedAssistant.time,
        const shared.MessageTime(created: 1779293101000, completed: 1779293102000),
      );
    });

    test("late native tool completion keeps its start time after turn completion", () {
      const threadId = "t-late-tool-time";
      mapper.map(
        const CodexServerNotification(
          method: "item/started",
          params: {
            "threadId": threadId,
            "startedAtMs": 1779293103000,
            "item": {
              "type": "commandExecution",
              "id": "i-late-tool-time",
              "command": "sleep 1",
              "status": "inProgress",
            },
          },
        ),
      );
      mapper.map(
        const CodexServerNotification(
          method: "turn/completed",
          params: {
            "threadId": threadId,
            "turn": {"id": "u-late-tool-time"},
          },
        ),
      );

      final completed = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": threadId,
            "completedAtMs": 1779293104000,
            "item": {
              "type": "commandExecution",
              "id": "i-late-tool-time",
              "command": "sleep 1",
              "status": "completed",
            },
          },
        ),
      );

      expect(
        shared.Message.fromJson((completed.first as BridgeSseMessageUpdated).info).time,
        const shared.MessageTime(created: 1779293103000, completed: 1779293104000),
      );
    });

    test("contextCompaction emits a durable tool lifecycle and completion signal", () {
      final started = mapper.map(
        const CodexServerNotification(
          method: "item/started",
          params: {
            "threadId": "t-1",
            "turnId": "u-compact",
            "item": {"type": "contextCompaction", "id": "cmp-1"},
          },
        ),
      );
      final completed = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-1",
            "turnId": "u-compact",
            "item": {"type": "contextCompaction", "id": "cmp-1"},
          },
        ),
      );

      expect(started, hasLength(2));
      expect(
        shared.Message.fromJson((started[0] as BridgeSseMessageUpdated).info),
        isA<shared.MessageAssistant>(),
      );
      final startedPart = (started[1] as BridgeSseMessagePartUpdated).part;
      expect(startedPart.tool, "compact");
      expect(startedPart.state?.title, "Compacting context");
      expect(startedPart.state?.status, PluginToolStatus.running);

      expect(completed, hasLength(3));
      final completedPart = (completed[1] as BridgeSseMessagePartUpdated).part;
      expect(completedPart.state?.title, "Context compacted");
      expect(completedPart.state?.status, PluginToolStatus.completed);
      expect(
        completed.whereType<BridgeSseSessionCompacted>().single.sessionID,
        "t-1",
      );
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
        imageAttachmentMapper: imageAttachmentMapper,
        imageBearingItemParser: imageBearingItemParser,
        rolloutToolMapper: rolloutToolMapper,
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
        imageAttachmentMapper: imageAttachmentMapper,
        imageBearingItemParser: imageBearingItemParser,
        rolloutToolMapper: rolloutToolMapper,
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
      final assistant = shared.Message.fromJson(
        (events[0] as BridgeSseMessageUpdated).info,
      ) as shared.MessageAssistant;
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
      final assistant2 = shared.Message.fromJson(
        (events2[0] as BridgeSseMessageUpdated).info,
      ) as shared.MessageAssistant;
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

      final running = rolloutLifecycle.mapRolloutLine(
        threadId: "t-raw",
        line: call,
      );
      final completed = rolloutLifecycle.mapRolloutLine(
        threadId: "t-raw",
        line: output,
      );
      final lateItem = rolloutLifecycle.map(
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
      expect(
        shared.Message.fromJson((running[0] as BridgeSseMessageUpdated).info).time,
        shared.MessageTime(created: DateTime.utc(2026, 7, 23, 8).millisecondsSinceEpoch, completed: null),
      );
      final rawPart = (completed[1] as BridgeSseMessagePartUpdated).part;
      final latePart = (lateItem[1] as BridgeSseMessagePartUpdated).part;
      expect(rawPart.state?.status, PluginToolStatus.error);
      expect(rawPart.state?.output, contains("Chunk ID: failed"));
      expect(latePart.state?.status, rawPart.state?.status);
      expect(latePart.state?.output, rawPart.state?.output);
      expect(latePart.state?.error, rawPart.state?.error);
      rolloutLifecycle.clearRolloutTurn(threadId: "t-raw");
    });

    test("projected wait results preserve earlier output", () {
      final call = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "custom_tool_call",
          "call_id": "call-long",
          "name": "exec",
          "input": "await tools.exec_command({cmd: 'sleep 30'});",
          "internal_chat_message_metadata_passthrough": {
            "turn_id": "turn-long",
          },
        },
      });
      final running = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "custom_tool_call_output",
          "call_id": "call-long",
          "output": "Script running with cell ID 7\nOutput:\nearly output\n",
        },
      });
      final wait = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "function_call",
          "call_id": "call-wait",
          "name": "wait",
          "arguments": '{"cell_id":"7"}',
          "internal_chat_message_metadata_passthrough": {
            "turn_id": "turn-long",
          },
        },
      });
      final completedWait = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "function_call_output",
          "call_id": "call-wait",
          "output": "Script completed with exit code 0\nFinal output:\nlate output\n",
        },
      });

      rolloutLifecycle
        ..mapRolloutLine(
          threadId: "t-long",
          line: call,
        )
        ..mapRolloutLine(
          threadId: "t-long",
          line: running,
        )
        ..mapRolloutLine(
          threadId: "t-long",
          line: wait,
        );
      final events = rolloutLifecycle.mapRolloutLine(
        threadId: "t-long",
        line: completedWait,
      );

      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.state?.status, PluginToolStatus.completed);
      expect(part.state?.output, contains("early output"));
      expect(part.state?.output, contains("late output"));
      rolloutLifecycle.clearRolloutTurn(threadId: "t-long");
    });

    test("turn-aborted rollout evidence closes running tools", () {
      final call = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "custom_tool_call",
          "call_id": "call-aborted",
          "name": "exec",
          "input": "await tools.exec_command({cmd: 'sleep 30'});",
          "internal_chat_message_metadata_passthrough": {
            "turn_id": "turn-aborted",
          },
        },
      });
      final running = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "custom_tool_call_output",
          "call_id": "call-aborted",
          "output": "Script running with cell ID 7\nOutput:\nearly output\n",
        },
      });
      final aborted = CodexRolloutLineDto.fromJson({
        "type": "event_msg",
        "payload": {
          "type": "turn_aborted",
          "turn_id": "turn-aborted",
        },
      });

      rolloutLifecycle
        ..mapRolloutLine(
          threadId: "t-aborted",
          line: call,
        )
        ..mapRolloutLine(
          threadId: "t-aborted",
          line: running,
        );
      final events = rolloutLifecycle.mapRolloutLine(
        threadId: "t-aborted",
        line: aborted,
      );

      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.messageID, "call-aborted");
      expect(part.state?.status, PluginToolStatus.error);
      expect(part.state?.output, contains("early output"));
      rolloutLifecycle.clearRolloutTurn(threadId: "t-aborted");
    });

    test("rollout terminal evidence completes an unresolved command", () {
      final call = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "function_call",
          "call_id": "call-app-server",
          "name": "exec_command",
          "arguments": '{"cmd":"sleep 30"}',
          "internal_chat_message_metadata_passthrough": {
            "turn_id": "turn-app-server",
          },
        },
      });
      final completed = CodexRolloutLineDto.fromJson({
        "type": "event_msg",
        "payload": {
          "type": "task_complete",
          "turn_id": "turn-app-server",
        },
      });

      rolloutLifecycle.mapRolloutLine(
        threadId: "t-app-server",
        line: call,
      );

      final events = rolloutLifecycle.mapRolloutLine(
        threadId: "t-app-server",
        line: completed,
      );
      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.messageID, "call-app-server");
      expect(part.state?.status, PluginToolStatus.completed);
      rolloutLifecycle.clearRolloutTurn(threadId: "t-app-server");
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
      rolloutLifecycle
        ..mapRolloutLine(
          threadId: "t-structured",
          line: call,
        )
        ..mapRolloutLine(
          threadId: "t-structured",
          line: output,
        );

      final events = rolloutLifecycle.map(
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
      rolloutLifecycle.clearRolloutTurn(threadId: "t-structured");
    });

    test("app-server completion overrides cached running rollout evidence", () {
      final call = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "function_call",
          "call_id": "call-completed",
          "name": "exec_command",
          "arguments": '{"cmd":"sleep 1"}',
        },
      });
      final running = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "function_call_output",
          "call_id": "call-completed",
          "output": "Script running with cell ID 7\nOutput:\n",
        },
      });
      rolloutLifecycle
        ..mapRolloutLine(
          threadId: "t-completed",
          line: call,
        )
        ..mapRolloutLine(
          threadId: "t-completed",
          line: running,
        );

      rolloutLifecycle.map(
        const CodexServerNotification(
          method: "item/started",
          params: {
            "threadId": "t-completed",
            "startedAtMs": 1779293200000,
            "item": {
              "type": "commandExecution",
              "id": "call-completed",
              "status": "inProgress",
            },
          },
        ),
      );

      final events = rolloutLifecycle.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-completed",
            "completedAtMs": 1779293201000,
            "item": {
              "type": "commandExecution",
              "id": "call-completed",
              "exitCode": 0,
              "status": "completed",
            },
          },
        ),
      );

      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.state?.status, PluginToolStatus.completed);
      expect(
        shared.Message.fromJson((events[0] as BridgeSseMessageUpdated).info).time,
        const shared.MessageTime(created: 1779293200000, completed: 1779293201000),
      );
      rolloutLifecycle.clearRolloutTurn(threadId: "t-completed");
    });

    test("clearing connection state removes metadata-less rollout tools", () {
      final call = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "custom_tool_call",
          "call_id": "call-stale",
          "name": "exec",
          "input": "await tools.exec_command({cmd: 'sleep 30'});",
        },
      });
      rolloutLifecycle.mapRolloutLine(
        threadId: "t-stale",
        line: call,
      );

      rolloutLifecycle.clearRolloutState();

      expect(
        rolloutLifecycle.mapRolloutLine(
          threadId: "t-stale",
          line: CodexRolloutLineDto.fromJson({
            "type": "event_msg",
            "payload": {
              "type": "task_complete",
              "turn_id": "turn-later",
            },
          }),
        ),
        isEmpty,
      );
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

      final events = rolloutLifecycle.mapRolloutLine(
        threadId: "t-unicode",
        line: line,
      );

      final title = (events[1] as BridgeSseMessagePartUpdated).part.state?.title;
      expect(title, "$prefix😀");
      expect(title?.runes, hasLength(120));
      rolloutLifecycle.clearRolloutTurn(threadId: "t-unicode");
    });

    test("image-generation rollout and app-server items converge on one stable part", () {
      final line = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "image_generation_call",
          "id": "image-1",
          "status": "completed",
          "result": "AA==",
        },
      });

      final rollout = rolloutLifecycle.mapRolloutLine(
        threadId: "t-image",
        line: line,
      );
      final appServer = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-image",
            "item": {
              "type": "imageGeneration",
              "id": "image-1",
              "status": "completed",
              "result": "AA==",
              "savedPath": null,
            },
          },
        ),
      );

      final rolloutPart = (rollout[1] as BridgeSseMessagePartUpdated).part;
      final appServerPart = (appServer[1] as BridgeSseMessagePartUpdated).part;
      expect(line, isA<CodexRolloutResponseItemLineDto>());
      expect(rolloutPart.id, "image-1-tool");
      expect(rolloutPart.messageID, "image-1");
      expect(rolloutPart.id, appServerPart.id);
      expect(rolloutPart.messageID, appServerPart.messageID);
      expect(rolloutPart.tool, appServerPart.tool);
      expect(rolloutPart.state?.status, appServerPart.state?.status);
      expect(rolloutPart.state?.attachments, appServerPart.state?.attachments);

      final idless = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "image_generation_call",
          "status": "completed",
          "result": "AA==",
        },
      });
      expect(
        rolloutLifecycle.mapRolloutLine(
          threadId: "t-image",
          line: idless,
        ),
        isEmpty,
      );
    });

    test("durable image-generation event preserves its saved filename", () {
      final line = CodexRolloutLineDto.fromJson({
        "timestamp": "2026-08-03T12:00:00Z",
        "type": "event_msg",
        "payload": {
          "type": "image_generation_end",
          "call_id": "image-durable",
          "status": "future-terminal-status",
          "revised_prompt": "private prompt",
          "result": "AA==",
          "saved_path": "/private/generated/final.png",
        },
      });

      final events = rolloutLifecycle.mapRolloutLine(
        threadId: "t-image-durable",
        line: line,
      );

      final part = (events[1] as BridgeSseMessagePartUpdated).part;
      expect(part.messageID, "image-durable");
      expect(part.tool, "image_generation");
      expect(part.state?.status, PluginToolStatus.completed);
      final attachment = part.state!.attachments.single as PluginMessageAttachmentInlineImage;
      expect(attachment.base64, "AA==");
      expect(attachment.filename, "final.png");

      final laterAppServerEvents = rolloutLifecycle.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-image-durable",
            "item": {
              "type": "imageGeneration",
              "id": "image-durable",
              "status": "completed",
              "revisedPrompt": null,
              "result": "AA==",
              "savedPath": null,
            },
          },
        ),
      );
      final laterPart = (laterAppServerEvents[1] as BridgeSseMessagePartUpdated).part;
      final laterAttachment = laterPart.state!.attachments.single as PluginMessageAttachmentInlineImage;
      expect(laterAttachment.filename, "final.png");
    });

    test("later app-server updates preserve richer rollout attachments", () {
      final call = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "custom_tool_call",
          "id": "tool-record",
          "call_id": "tool-live",
          "name": "exec",
          "input": 'tools.exec_command({"cmd":"capture"})',
        },
      });
      final result = CodexRolloutLineDto.fromJson({
        "type": "response_item",
        "payload": {
          "type": "custom_tool_call_output",
          "call_id": "tool-live",
          "output": [
            {"type": "input_text", "text": "persisted output"},
            {"type": "input_image", "image_url": "data:image/png;base64,AA=="},
          ],
        },
      });
      rolloutLifecycle.mapRolloutLine(
        threadId: "t-canonical-image",
        line: call,
      );
      final rolloutEvents = rolloutLifecycle.mapRolloutLine(
        threadId: "t-canonical-image",
        line: result,
      );

      final appServerEvents = rolloutLifecycle.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-canonical-image",
            "item": {
              "type": "dynamicToolCall",
              "id": "tool-live",
              "tool": "exec",
              "arguments": null,
              "status": "completed",
              "contentItems": [
                {"type": "inputText", "text": "smaller app-server output"},
              ],
            },
          },
        ),
      );

      final rolloutPart = (rolloutEvents[1] as BridgeSseMessagePartUpdated).part;
      final appServerPart = (appServerEvents[1] as BridgeSseMessagePartUpdated).part;
      expect(appServerPart.id, rolloutPart.id);
      expect(appServerPart.state?.output, "persisted output");
      expect(appServerPart.state?.attachments, rolloutPart.state?.attachments);
      expect(appServerPart.state?.attachments.single, isA<PluginMessageAttachmentInlineImage>());
      rolloutLifecycle.clearRolloutTurn(threadId: "t-canonical-image");
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

    test("imageGeneration upserts one stable tool part across its lifecycle", () {
      List<BridgeSseEvent> mapImage({
        required String method,
        required String status,
        required String result,
      }) {
        return mapper.map(
          CodexServerNotification(
            method: method,
            params: {
              "threadId": "t-1",
              "item": {
                "type": "imageGeneration",
                "id": "i-image",
                "status": status,
                "revisedPrompt": "private prompt",
                "result": result,
                "savedPath": "/private/output.png",
              },
            },
          ),
        );
      }

      final started = mapImage(method: "item/started", status: "in_progress", result: "");
      final completed = mapImage(method: "item/completed", status: "completed", result: "AA==");
      final failed = mapImage(method: "item/completed", status: "failed", result: "AA==");

      final runningPart = (started[1] as BridgeSseMessagePartUpdated).part;
      final completedPart = (completed[1] as BridgeSseMessagePartUpdated).part;
      final failedPart = (failed[1] as BridgeSseMessagePartUpdated).part;
      expect(started, hasLength(2));
      expect(runningPart.id, "i-image-tool");
      expect(runningPart.messageID, "i-image");
      expect(runningPart.tool, "image_generation");
      expect(runningPart.state?.status, PluginToolStatus.running);
      expect(runningPart.state?.title, isNull);
      expect(runningPart.state?.attachments, isEmpty);
      expect(completedPart.id, runningPart.id);
      expect(completedPart.state?.status, PluginToolStatus.completed);
      final image = completedPart.state!.attachments.single as PluginMessageAttachmentInlineImage;
      expect(image.mime, "image/png");
      expect(image.base64, "AA==");
      expect(image.filename, "output.png");
      expect(completedPart.toString(), isNot(contains("private prompt")));
      expect(completedPart.toString(), isNot(contains("/private/")));
      expect(failedPart.id, runningPart.id);
      expect(failedPart.state?.status, PluginToolStatus.error);
      expect(failedPart.state?.attachments, isEmpty);
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
              "result": {
                "content": [
                  {"type": "text", "text": "before "},
                  {"type": "image", "data": "AA==", "mimeType": "image/png"},
                  {"type": "image", "data": "AA==", "mimeType": "image/png"},
                  {"type": "image", "data": "AA==", "mimeType": "image/png"},
                  {"type": "image", "data": "AA==", "mimeType": "image/png"},
                  {"type": "image", "data": "AA==", "mimeType": "image/png"},
                  {"type": "text", "text": "after"},
                ],
              },
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
      expect(part.state?.output, "before after");
      expect(part.state?.error, "element not found");
      expect(part.state?.attachments, hasLength(4));
      expect(part.state?.attachments, everyElement(isA<PluginMessageAttachmentInlineImage>()));
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
                {"type": "inputImage", "imageUrl": "data:image/png;base64,AA=="},
                {"type": "inputImage", "imageUrl": "https://example.com/private/remote.png?token=secret"},
                {"type": "inputAudio", "audioUrl": "data:audio/wav;base64,AA=="},
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
      expect(completedPart.state?.attachments, hasLength(2));
      expect(completedPart.state?.attachments[0], isA<PluginMessageAttachmentInlineImage>());
      final remote = completedPart.state!.attachments[1] as PluginMessageAttachmentMetadata;
      expect(remote.mime, "application/octet-stream");
      expect(remote.filename, "remote.png");
    });

    test("imageView local paths remain unsupported", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "item/completed",
          params: {
            "threadId": "t-1",
            "item": {
              "type": "imageView",
              "id": "i-view",
              "path": "/private/output.png",
            },
          },
        ),
      );

      expect(events, isEmpty);
    });

    test("dynamicToolCall falls back for malformed or empty tool names", () {
      for (final (rawTool, method, status, expectedStatus) in <(Object?, String, Object?, PluginToolStatus)>[
        (42, "item/started", "future_status", PluginToolStatus.running),
        ("", "item/completed", null, PluginToolStatus.completed),
      ]) {
        final events = mapper.map(
          CodexServerNotification(
            method: method,
            params: {
              "threadId": "t-1",
              "item": {
                "type": "dynamicToolCall",
                "id": "i-fallback",
                "tool": rawTool,
                "arguments": const <String, Object?>{},
                "status": status,
              },
            },
          ),
        );

        final part = (events[1] as BridgeSseMessagePartUpdated).part;
        expect(part.tool, "tool");
        expect(part.state?.status, expectedStatus);
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

    test("failed turn/completed emits a visible error message", () {
      final events = mapper.map(
        const CodexServerNotification(
          method: "turn/completed",
          params: {
            "threadId": "t-quota",
            "turn": {
              "id": "u-quota",
              "status": "failed",
              "error": {
                "message": "You've hit your usage limit.",
                "codexErrorInfo": "usageLimitExceeded",
              },
              "startedAt": 1700000005,
              "completedAt": 1700000010,
            },
          },
        ),
      );

      expect(events, hasLength(3));
      final event = events[1] as BridgeSseMessageUpdated;
      final message = shared.Message.fromJson(event.info) as shared.MessageError;
      expect(message.id, "u-quota");
      expect(message.sessionID, "t-quota");
      expect(message.errorName, "CodexError");
      expect(message.errorMessage, "You've hit your usage limit.");
      expect(message.time, const shared.MessageTime(created: 1700000010000, completed: 1700000010000));
      expect(parseAsSesori(event), isA<shared.SesoriMessageUpdated>());
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

    test("skills/changed invalidates the command catalog", () {
      final events = mapper.map(
        const CodexServerNotification(method: "skills/changed", params: {}),
      );

      expect(events, const [BridgeSseCommandCatalogUpdated()]);
    });

    test("MCP startup changes invalidate MCP tools", () {
      final events = mapper.map(
        const CodexServerNotification(method: "mcpServer/startupStatus/updated", params: {}),
      );

      expect(events, const [BridgeSseMcpToolsChanged()]);
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

class _ToolLifecycleHarness({
  required final CodexEventMapper _eventMapper,
  required final CodexToolLifecycleTracker _toolTracker,
}) {
  List<BridgeSseEvent> mapRolloutLine({
    required String threadId,
    required CodexRolloutLineDto line,
  }) {
    final events = <BridgeSseEvent>[];
    for (final tool in _toolTracker.observeRolloutLine(threadId: threadId, line: line)) {
      events.addAll(
        _eventMapper.mapProjectedTool(threadId: threadId, tool: tool),
      );
    }
    return events;
  }

  List<BridgeSseEvent> map(CodexServerNotification notification) {
    final correlatableItem =
        const CodexCommandExecutionParser().parse(
          notification: notification,
        ) ??
        const CodexFileChangeParser().parse(notification: notification);
    final item = notification.params["item"];
    final image = item is Map
        ? const CodexImageBearingItemParser().parse(
            item: Map<String, dynamic>.from(item),
          )
        : null;
    final tool = correlatableItem == null
        ? _toolTracker.observeUncorrelatedAppServerItem(
            notification: notification,
            imageGeneration: image is CodexImageGenerationItemDto ? image : null,
          )
        : _toolTracker.observeCorrelatableAppServerItem(
            event: correlatableItem,
            notification: notification,
          );
    final threadId = correlatableItem?.threadId ?? notification.params["threadId"];
    if (tool == null || threadId is! String) {
      return _eventMapper.map(notification);
    }
    return _eventMapper.mapProjectedTool(threadId: threadId, tool: tool);
  }

  void clearRolloutTurn({required String threadId}) {
    _toolTracker.clearThread(threadId: threadId);
  }

  void clearRolloutState() {
    _toolTracker.clear();
  }
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

class _BufferingStdout() implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
