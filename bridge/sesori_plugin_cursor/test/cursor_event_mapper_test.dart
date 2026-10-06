import "dart:io";
import "dart:typed_data";

import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:cursor_plugin/src/repositories/cursor_generated_image_reader.dart";
import "package:cursor_plugin/src/repositories/mappers/cursor_subagent_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CursorEventMapper", () {
    CursorEventMapper buildMapper({
      String? Function()? activeSessionResolver,
      AcpChildSessionTracker? childSessions,
      AcpSessionConfigurationTracker? configurationTracker,
    }) {
      return CursorEventMapper(
        launchDirectory: "/repo",
        pluginId: CursorPlugin.pluginId,
        configurationTracker: configurationTracker ?? AcpSessionConfigurationTracker(),
        childSessions: childSessions ?? AcpChildSessionTracker(),
        generatedImageReader: const CursorGeneratedImageReader(),
        subagentMapper: const CursorSubagentMapper(),
        activeSessionResolver: activeSessionResolver ?? () => null,
      );
    }

    final mapper = buildMapper();

    // Microsecond-stamped names: parallel worktrees run this suite against the
    // same systemTemp concurrently, so fixed names can race.
    File writeTempPng(String prefix) {
      final file = File(
        "${Directory.systemTemp.path}/$prefix-${DateTime.now().microsecondsSinceEpoch}.png",
      );
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      file.writeAsBytesSync(
        Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
      );
      return file;
    }

    test("cursor/update_todos maps to a todo update", () {
      final events = mapper.map(
        const AcpNotification(
          method: "cursor/update_todos",
          params: {"sessionId": "s1", "todos": <Object?>[]},
        ),
      );
      expect(events.single, isA<BridgeSseTodoUpdated>());
      expect((events.single as BridgeSseTodoUpdated).sessionID, "s1");
    });

    test("standard session/update still works via the base mapper", () {
      mapper.beginTurn(sessionId: "s1", messageId: null);
      final events = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "s1",
            "update": {
              "sessionUpdate": "agent_message_chunk",
              "content": {"type": "text", "text": "hi"},
            },
          },
        ),
      );
      expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, "hi");
    });

    group("native sub-agents", () {
      late AcpChildSessionTracker childSessions;
      late AcpSessionConfigurationTracker configurationTracker;
      late CursorEventMapper target;

      setUp(() {
        childSessions = AcpChildSessionTracker();
        configurationTracker = AcpSessionConfigurationTracker();
        target = buildMapper(childSessions: childSessions, configurationTracker: configurationTracker)
          ..beginTurn(sessionId: "root", messageId: "turn-1");
      });

      AcpNotification update({required String sessionId, required Map<String, dynamic> update}) =>
          AcpNotification(method: AcpMethods.sessionUpdate, params: {"sessionId": sessionId, "update": update});

      AcpNotification taskCall({required String sessionId, required String toolCallId}) => update(
        sessionId: sessionId,
        update: {
          "sessionUpdate": "tool_call",
          "toolCallId": toolCallId,
          "title": "Task",
          "kind": "think",
          "status": "pending",
          "rawInput": {
            "_toolName": "task",
            "prompt": "Inspect the parser for edge cases",
            "description": "Inspect parser",
            "subagentType": {"unspecified": <String, Object?>{}},
          },
        },
      );

      AcpNotification spawned({
        required String sessionId,
        required String childSessionId,
        required String task,
        required String? toolCallId,
        required String? model,
      }) => update(
        sessionId: sessionId,
        update: {
          "sessionUpdate": "subagent_spawned",
          "subagentSessionId": childSessionId,
          "name": "explore",
          "task": task,
          "capabilities": <String, Object?>{},
          "_meta": {
            "cursor": {"toolCallId": ?toolCallId, "agentId": "agent-1", "model": ?model},
          },
        },
      );

      AcpNotification state({required String sessionId, required String childSessionId, required String state}) =>
          update(
            sessionId: sessionId,
            update: {
              "sessionUpdate": "subagent_state_update",
              "subagentSessionId": childSessionId,
              "state": state,
              "_meta": {
                "cursor": {"toolCallId": "task-1", "agentId": "agent-1"},
              },
            },
          );

      PluginMessagePartSubtask tile(List<BridgeSseEvent> events) => events
          .whereType<BridgeSseMessagePartUpdated>()
          .map((event) => event.part)
          .whereType<PluginMessagePartSubtask>()
          .single;

      test("a Task call renders no generic card; the spawn opens one linked tile", () {
        expect(target.map(taskCall(sessionId: "root", toolCallId: "task-1")), isEmpty);

        final events = target.map(
          spawned(
            sessionId: "root",
            childSessionId: "agent-1",
            task: "Parser audit",
            toolCallId: "task-1",
            model: null,
          ),
        );

        final created = events.whereType<BridgeSseSessionCreated>().single.info;
        expect(created["id"], "agent-1");
        expect(created["parentID"], "root");
        final subtask = tile(events);
        expect(subtask.childSessionID, "agent-1");
        expect(subtask.agent, "explore");
        expect(subtask.description, "Parser audit");
        expect(subtask.prompt, "Inspect the parser for edge cases");
        expect(childSessions.runningChildren(sessionId: "root").single.isBackground, isFalse);
      });

      test("a blank task falls back to the Task description; no Task input falls back to the task", () {
        target.map(taskCall(sessionId: "root", toolCallId: "task-1"));
        final fromInput = tile(
          target.map(
            spawned(sessionId: "root", childSessionId: "agent-1", task: "", toolCallId: "task-1", model: null),
          ),
        );
        expect(fromInput.description, "Inspect parser");

        final fromTask = tile(
          target.map(
            spawned(sessionId: "root", childSessionId: "agent-2", task: "Lint audit", toolCallId: null, model: null),
          ),
        );
        expect(fromTask.prompt, "Lint audit");
        expect(fromTask.description, "Lint audit");
      });

      test("a nested child resolves its root and the announced model sticks to the child", () {
        target.map(
          spawned(sessionId: "root", childSessionId: "agent-1", task: "Outer", toolCallId: null, model: "gpt-5"),
        );
        final nested = target.map(
          spawned(sessionId: "agent-1", childSessionId: "agent-2", task: "Inner", toolCallId: null, model: null),
        );

        expect(nested.whereType<BridgeSseSessionCreated>().single.info["parentID"], "agent-1");
        expect(childSessions.rootOf(sessionId: "agent-2"), "root");
        expect(childSessions.runningChildren(sessionId: "root"), hasLength(2));
        expect(configurationTracker.snapshotForSession(sessionId: "agent-1").modelId, "gpt-5");
      });

      test("a resumed run is a new .n child after the first one finished", () {
        target
          ..map(spawned(sessionId: "root", childSessionId: "agent-1", task: "Run", toolCallId: null, model: null))
          ..map(state(sessionId: "root", childSessionId: "agent-1", state: "completed"));

        final resumed = target.map(
          spawned(sessionId: "root", childSessionId: "agent-1.1", task: "Run again", toolCallId: null, model: null),
        );

        expect(tile(resumed).childSessionID, "agent-1.1");
        expect(childSessions.runningChildren(sessionId: "root").single.childSessionId, "agent-1.1");
      });

      for (final (wire, status, hasError) in const [
        ("completed", PluginToolStatus.completed, false),
        ("failed", PluginToolStatus.error, true),
        ("cancelled", PluginToolStatus.cancelled, false),
        ("disconnected", PluginToolStatus.error, true),
      ]) {
        test("state $wire settles the tile as ${status.name}", () {
          target.map(spawned(sessionId: "root", childSessionId: "agent-1", task: "Run", toolCallId: null, model: null));

          final settled = tile(target.map(state(sessionId: "root", childSessionId: "agent-1", state: wire)));

          expect(settled.taskState?.status, status);
          expect(settled.taskState?.error, hasError ? isNotNull : isNull);
          expect(childSessions.runningChildren(sessionId: "root"), isEmpty);
        });
      }

      test("an unknown state finishes nothing", () {
        target.map(spawned(sessionId: "root", childSessionId: "agent-1", task: "Run", toolCallId: null, model: null));

        expect(target.map(state(sessionId: "root", childSessionId: "agent-1", state: "paused")), isEmpty);
        expect(childSessions.runningChildren(sessionId: "root"), hasLength(1));
      });

      test("malformed sub-agent frames are dropped", () {
        expect(
          target.map(update(sessionId: "root", update: {"sessionUpdate": "subagent_spawned", "name": "explore"})),
          isEmpty,
        );
        expect(
          target.map(update(sessionId: "root", update: {"sessionUpdate": "subagent_state_update", "state": 7})),
          isEmpty,
        );
        expect(childSessions.runningChildren(sessionId: "root"), isEmpty);
      });

      test("cursor/task is no longer mapped", () {
        target.map(taskCall(sessionId: "root", toolCallId: "task-1"));

        expect(
          target.map(
            const AcpNotification(
              method: "cursor/task",
              params: {
                "toolCallId": "task-1",
                "description": "Inspect parser",
                "prompt": "Inspect the parser for edge cases",
                "subagentType": {
                  "custom": {"unspecified": <String, Object?>{}},
                },
              },
            ),
          ),
          isEmpty,
        );
      });
    });

    test("cursor/generate_image maps to a standard inline file part", () async {
      mapper.beginTurn(sessionId: "s-image", messageId: null);
      final file = writeTempPng("cursor-event-mapper");

      final part = mapper
          .map(
            AcpNotification(
              method: "cursor/generate_image",
              params: {"sessionId": "s-image", "filePath": file.path},
            ),
          )
          .whereType<BridgeSseMessagePartUpdated>()
          .single
          .part;
      expect(part.type, PluginMessagePartType.file);
      expect(part.sessionID, "s-image");
    });

    test("cursor/generate_image finalizes active reasoning before the image", () async {
      final imageMapper = buildMapper();
      imageMapper.beginTurn(sessionId: "s-thinking-image", messageId: null);
      imageMapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "s-thinking-image",
            "update": {
              "sessionUpdate": "agent_thought_chunk",
              "content": {"type": "text", "text": "Designing the image"},
            },
          },
        ),
      );
      final file = writeTempPng("cursor-reasoning-image");

      final events = imageMapper.map(
        AcpNotification(
          method: "cursor/generate_image",
          params: {"sessionId": "s-thinking-image", "filePath": file.path},
        ),
      );

      final parts = events.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part).toList();
      expect(parts, hasLength(2));
      expect(parts.first.type, PluginMessagePartType.reasoning);
      expect((parts.first as PluginMessagePartReasoning).text, "Designing the image");
      expect(parts.last.type, PluginMessagePartType.file);
    });

    test("cursor/generate_image accepts legacy path params", () async {
      mapper.beginTurn(sessionId: "s-image-legacy", messageId: null);
      final file = writeTempPng("cursor-event-mapper-legacy");

      expect(
        mapper
            .map(
              AcpNotification(
                method: "cursor/generate_image",
                params: {"sessionId": "s-image-legacy", "path": file.path},
              ),
            )
            .whereType<BridgeSseMessagePartUpdated>()
            .single
            .part
            .type,
        PluginMessagePartType.file,
      );
    });

    test("cursor/generate_image resolves sessionId from the plugin's active turn", () async {
      // No sessionId and no toolCallId in the payload: attribution comes from
      // the plugin-supplied resolver, not any mapper-side turn tracking.
      final turnMapper = buildMapper(activeSessionResolver: () => "s-active");
      final file = writeTempPng("cursor-active-turn-image");

      final part = turnMapper
          .map(
            AcpNotification(
              method: "cursor/generate_image",
              params: {"filePath": file.path, "description": "test"},
            ),
          )
          .whereType<BridgeSseMessagePartUpdated>()
          .single
          .part;
      expect(part.type, PluginMessagePartType.file);
      expect(part.sessionID, "s-active");
    });

    test("cursor/generate_image prefers the originating toolCallId over the active turn", () async {
      // The resolver answers a different session than the one owning the tool
      // call, so this fails if the toolCallId chain is broken or deleted.
      final chainMapper = buildMapper(activeSessionResolver: () => "s-other");
      final file = writeTempPng("cursor-toolcall-image");

      chainMapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "sA",
            "update": {
              "sessionUpdate": "tool_call",
              "toolCallId": "img-tool-1",
              "title": "Generate Image: test",
              "status": "completed",
            },
          },
        ),
      );

      final part = chainMapper
          .map(
            AcpNotification(
              method: "cursor/generate_image",
              params: {
                "toolCallId": "img-tool-1",
                "filePath": file.path,
                "description": "test",
              },
            ),
          )
          .whereType<BridgeSseMessagePartUpdated>()
          .single
          .part;
      expect(part.type, PluginMessagePartType.file);
      expect(part.sessionID, "sA");
    });

    test("cursor/generate_image rejects a relative source path, even one that exists", () {
      // A relative path resolves against the bridge process CWD, not the
      // session's project — it must be rejected at the boundary, never read.
      final name = "cursor-relative-image-${DateTime.now().microsecondsSinceEpoch}.png";
      final file = File(name);
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      file.writeAsBytesSync(
        Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
      );

      final relativeMapper = buildMapper(activeSessionResolver: () => "s-rel");
      expect(
        relativeMapper.map(
          AcpNotification(
            method: "cursor/generate_image",
            params: {"sessionId": "s-rel", "filePath": name},
          ),
        ),
        isEmpty,
      );
    });

    test("cursor/generate_image with no resolvable session drops the payload", () async {
      // No sessionId, no toolCallId, resolver answers null: the payload must be
      // dropped — an event stamped with "" would be discarded by the client.
      final orphanMapper = buildMapper();
      final file = writeTempPng("cursor-orphan-image");

      expect(
        orphanMapper.map(
          AcpNotification(
            method: "cursor/generate_image",
            params: {"filePath": file.path, "description": "test"},
          ),
        ),
        isEmpty,
      );
    });

    test("generate_image lands as an ordered part inside the live assistant message", () {
      // The whole point of routing through appendAssistantImageBlocks is that
      // the image joins the in-progress assistant message in stream order,
      // instead of being emitted as a standalone sidecar message.
      final orderedMapper = buildMapper();
      orderedMapper.beginTurn(sessionId: "s1", messageId: null);
      final file = writeTempPng("cursor-ordered-image");
      const messageId = "s1-t1-assistant-a0";

      AcpNotification textChunk(String text) => AcpNotification(
        method: "session/update",
        params: {
          "sessionId": "s1",
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": text},
          },
        },
      );

      final first = orderedMapper.map(textChunk("Here it is:"));
      final image = orderedMapper.map(
        AcpNotification(
          method: "cursor/generate_image",
          params: {"sessionId": "s1", "filePath": file.path},
        ),
      );
      final second = orderedMapper.map(textChunk("Done."));

      expect(first.whereType<BridgeSseMessagePartDelta>().single.partID, "$messageId-text");

      final imagePart = image.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(imagePart.id, "$messageId-image-1");
      expect(imagePart.messageID, messageId);
      expect(
        image.whereType<BridgeSseMessageUpdated>(),
        isEmpty,
        reason: "the image must join the live message, not open a new envelope",
      );

      expect(second.whereType<BridgeSseMessagePartDelta>().single.partID, "$messageId-text-1");
      expect(second.whereType<BridgeSseMessageUpdated>(), isEmpty);
    });

    test("standard ACP images still work alongside cursor generate_image", () {
      mapper.beginTurn(sessionId: "s-image", messageId: null);
      final standard = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "s-image",
            "update": {
              "sessionUpdate": "agent_message_chunk",
              "content": {
                "type": "image",
                "data": "AA==",
                "mimeType": "image/png",
                "uri": null,
              },
            },
          },
        ),
      );
      expect(
        standard.whereType<BridgeSseMessagePartUpdated>().single.part.type,
        PluginMessagePartType.file,
      );
    });

    test("an account/plan gate notice becomes an error message, not assistant text", () {
      mapper.beginTurn(sessionId: "sg", messageId: null);
      final events = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "sg",
            "update": {
              "sessionUpdate": "agent_message_chunk",
              // Exact wire capture from cursor-agent when a gated model is used.
              "content": {"type": "text", "text": "\n\nCheck your settings to continue"},
            },
          },
        ),
      );
      final message = events.whereType<BridgeSseMessageUpdated>().single.info;
      expect(message, isA<PluginMessageError>());
      expect(
        (message as PluginMessageError).errorMessage,
        "\n\nCheck your settings to continue",
      );
      expect(events.whereType<BridgeSseMessagePartDelta>(), isEmpty);
    });

    test("gate matching tolerates case and surrounding decoration", () {
      expect(mapper.classifyHaltNotice(text: "  CHECK YOUR SETTINGS TO CONTINUE.  "), isNotNull);
      expect(mapper.classifyHaltNotice(text: "⚠️ Check your settings to continue"), isNotNull);
    });

    test("non-ASCII letters are content, not strippable decoration", () {
      // Letters (any script) adjacent to the phrase mean the message is more
      // than the gate notice; only punctuation/symbol/emoji decoration is
      // stripped before the exact match.
      expect(mapper.classifyHaltNotice(text: "É Check your settings to continue"), isNull);
    });

    test("ordinary prose that merely contains the phrase is not a gate", () {
      expect(
        mapper.classifyHaltNotice(
          text: "Sure — check your settings to continue setting up the project, then rerun.",
        ),
        isNull,
      );
    });
  });
}
