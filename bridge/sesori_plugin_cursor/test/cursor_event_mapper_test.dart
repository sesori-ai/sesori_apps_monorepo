import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:cursor_plugin/src/repositories/cursor_generated_image_reader.dart";
import "package:cursor_plugin/src/trackers/cursor_task_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CursorEventMapper", () {
    CursorEventMapper buildMapper({
      String? Function()? activeSessionResolver,
      CursorTaskTracker? taskTracker,
    }) {
      return CursorEventMapper(
        launchDirectory: "/repo",
        pluginId: CursorPlugin.pluginId,
        configurationTracker: AcpSessionConfigurationTracker(),
        childSessions: AcpChildSessionTracker(),
        generatedImageReader: const CursorGeneratedImageReader(),
        taskTracker: taskTracker ?? CursorTaskTracker(),
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

    List<BridgeSseEvent> taskUpdate({
      required CursorEventMapper target,
      required String sessionId,
      required String toolCallId,
      required String status,
      required bool starts,
      required Object? rawOutput,
    }) => target.map(
      AcpNotification(
        method: AcpMethods.sessionUpdate,
        params: {
          "sessionId": sessionId,
          "update": {
            "sessionUpdate": starts ? "tool_call" : "tool_call_update",
            "toolCallId": toolCallId,
            "title": "Task: inspect",
            "status": status,
            "rawInput": {"_toolName": "task"},
            "rawOutput": ?rawOutput,
          },
        },
      ),
    );

    AcpNotification taskRequest({
      required String toolCallId,
      required String? sessionId,
      required Object? subagentType,
      required String prompt,
      required String description,
    }) => AcpNotification(
      method: "cursor/task",
      params: {
        "toolCallId": toolCallId,
        "description": description,
        "prompt": prompt,
        "subagentType": subagentType,
        "sessionId": ?sessionId,
      },
    );

    void completeForeground({
      required CursorEventMapper target,
      required String sessionId,
      required String toolCallId,
    }) {
      taskUpdate(
        target: target,
        sessionId: sessionId,
        toolCallId: toolCallId,
        status: "pending",
        starts: true,
        rawOutput: null,
      );
      taskUpdate(
        target: target,
        sessionId: sessionId,
        toolCallId: toolCallId,
        status: "completed",
        starts: false,
        rawOutput: const {"durationMs": 42, "isBackground": false},
      );
    }

    AcpNotification validTaskRequest({required String toolCallId, required String? sessionId}) => taskRequest(
      toolCallId: toolCallId,
      sessionId: sessionId,
      subagentType: const {"custom": "unspecified"},
      prompt: "Inspect code",
      description: "Inspect",
    );

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

    test("malformed cursor/task extensions are dropped", () {
      expect(
        mapper.map(const AcpNotification(method: "cursor/task", params: {})),
        isEmpty,
      );
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

    test("Task correlation has only activeModeUnknown and foregroundCompleted phases", () {
      expect(CursorTaskPhase.values, [CursorTaskPhase.activeModeUnknown, CursorTaskPhase.foregroundCompleted]);
    });

    test("foreground Task stays generic until cursor/task replaces its exact part once", () {
      final childSessions = AcpChildSessionTracker();
      final target = CursorEventMapper(
        launchDirectory: "/repo",
        pluginId: CursorPlugin.pluginId,
        configurationTracker: AcpSessionConfigurationTracker(),
        childSessions: childSessions,
        generatedImageReader: const CursorGeneratedImageReader(),
        taskTracker: CursorTaskTracker(),
        activeSessionResolver: () => "other-root",
      );
      target.beginTurn(sessionId: "root", messageId: "turn-1");
      final pending = taskUpdate(
        target: target,
        sessionId: "root",
        toolCallId: "task-1",
        status: "pending",
        starts: true,
        rawOutput: null,
      ).whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(pending, isA<PluginMessagePartTool>());
      final running =
          taskUpdate(
                target: target,
                sessionId: "root",
                toolCallId: "task-1",
                status: "in_progress",
                starts: false,
                rawOutput: null,
              ).whereType<BridgeSseMessagePartUpdated>().single.part
              as PluginMessagePartTool;
      expect(running.state.status, PluginToolStatus.running);
      final completed = taskUpdate(
        target: target,
        sessionId: "root",
        toolCallId: "task-1",
        status: "completed",
        starts: false,
        rawOutput: const {"durationMs": 42, "isBackground": false},
      ).whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(completed, isA<PluginMessagePartTool>());

      final tile =
          target
                  .map(validTaskRequest(toolCallId: "task-1", sessionId: null))
                  .whereType<BridgeSseMessagePartUpdated>()
                  .single
                  .part
              as PluginMessagePartSubtask;
      expect((tile.id, tile.messageID, tile.sessionID), (pending.id, pending.messageID, "root"));
      expect((tile.prompt, tile.description, tile.agent), ("Inspect code", "Inspect", "unspecified"));
      expect(tile.taskState?.status, PluginToolStatus.completed);
      expect(tile.childSessionID, isNull, reason: "agentId and tool ids never become child identity");
      expect(childSessions.childStatuses, isEmpty);
      expect(childSessions.hasActiveWork, isFalse);
      expect(childSessions.activeRootSessionIds, isEmpty);
      expect(target.map(validTaskRequest(toolCallId: "task-1", sessionId: null)), isEmpty);
    });

    test("background, failed, cancelled, unknown, and malformed Task updates stay generic", () {
      for (final taskCase in <({String id, String status, Object? output})>[
        (id: "background", status: "completed", output: const {"isBackground": true}),
        (id: "failed", status: "failed", output: null),
        (id: "cancelled", status: "cancelled", output: null),
        (id: "unknown", status: "future", output: null),
        (id: "missing", status: "completed", output: const {"durationMs": 5}),
        (id: "malformed", status: "completed", output: const {"isBackground": "false"}),
      ]) {
        final target = buildMapper(activeSessionResolver: () => "root");
        target.beginTurn(sessionId: "root", messageId: "turn");
        taskUpdate(
          target: target,
          sessionId: "root",
          toolCallId: taskCase.id,
          status: "pending",
          starts: true,
          rawOutput: null,
        );
        expect(
          taskUpdate(
            target: target,
            sessionId: "root",
            toolCallId: taskCase.id,
            status: taskCase.status,
            starts: false,
            rawOutput: taskCase.output,
          ).whereType<BridgeSseMessagePartUpdated>().single.part,
          isA<PluginMessagePartTool>(),
        );
        expect(target.map(validTaskRequest(toolCallId: taskCase.id, sessionId: null)), isEmpty);
        final settlement = target.mapPromptResult(sessionId: "root", stopReason: AcpStopReason.cancelled);
        if (taskCase.status == "cancelled" || taskCase.status == "future") {
          final settledPart = (settlement.single as BridgeSseMessagePartUpdated).part as PluginMessagePartTool;
          expect(settledPart.state.status, PluginToolStatus.cancelled);
        } else {
          expect(settlement, isEmpty);
        }
      }
    });

    test("an initial Task correlates only completion and keeps unknown status settleable", () {
      final completed = buildMapper(activeSessionResolver: () => "root")
        ..beginTurn(sessionId: "root", messageId: "turn");
      expect(
        taskUpdate(
          target: completed,
          sessionId: "root",
          toolCallId: "initial-completed",
          status: "completed",
          starts: true,
          rawOutput: const {"isBackground": false},
        ).whereType<BridgeSseMessagePartUpdated>().single.part,
        isA<PluginMessagePartTool>(),
      );
      expect(
        completed
            .map(validTaskRequest(toolCallId: "initial-completed", sessionId: null))
            .whereType<BridgeSseMessagePartUpdated>()
            .single
            .part,
        isA<PluginMessagePartSubtask>(),
      );

      for (final taskCase in <({String id, String status, Object? output})>[
        (id: "initial-background", status: "completed", output: const {"isBackground": true}),
        (id: "initial-failed", status: "failed", output: null),
        (id: "initial-cancelled", status: "cancelled", output: null),
        (id: "initial-unknown", status: "future", output: null),
        (id: "initial-missing", status: "completed", output: const {"durationMs": 5}),
        (id: "initial-malformed-output", status: "completed", output: const {"isBackground": "false"}),
      ]) {
        final target = buildMapper(activeSessionResolver: () => "root")
          ..beginTurn(sessionId: "root", messageId: "turn");
        taskUpdate(
          target: target,
          sessionId: "root",
          toolCallId: taskCase.id,
          status: taskCase.status,
          starts: true,
          rawOutput: taskCase.output,
        );
        expect(target.map(validTaskRequest(toolCallId: taskCase.id, sessionId: null)), isEmpty);
        final settlement = target.mapPromptResult(sessionId: "root", stopReason: AcpStopReason.cancelled);
        if (taskCase.status == "cancelled" || taskCase.status == "future") {
          final settledPart = (settlement.single as BridgeSseMessagePartUpdated).part as PluginMessagePartTool;
          expect(settledPart.state.status, PluginToolStatus.cancelled);
        } else {
          expect(settlement, isEmpty, reason: "a known unsupported terminal must leave no active Task record");
        }
      }

      final malformedInput = buildMapper(activeSessionResolver: () => "root")
        ..beginTurn(sessionId: "root", messageId: "turn");
      malformedInput.map(
        const AcpNotification(
          method: AcpMethods.sessionUpdate,
          params: {
            "sessionId": "root",
            "update": {
              "sessionUpdate": "tool_call",
              "toolCallId": "initial-malformed-input",
              "title": "Task: inspect",
              "status": "completed",
              "rawInput": {"_toolName": 7},
              "rawOutput": {"isBackground": false},
            },
          },
        ),
      );
      expect(
        malformedInput.map(validTaskRequest(toolCallId: "initial-malformed-input", sessionId: null)),
        isEmpty,
      );
      expect(
        malformedInput.mapPromptResult(sessionId: "root", stopReason: AcpStopReason.cancelled),
        isEmpty,
      );
    });

    test("incomplete and unknown completed requests retain generic card and consume correlation", () {
      for (final requestCase in <({String prompt, String description, Object type})>[
        (prompt: " ", description: "Inspect", type: const {"custom": "unspecified"}),
        (prompt: "Inspect code", description: "", type: const {"custom": "unspecified"}),
        (prompt: "Inspect code", description: "Inspect", type: const <String, Object?>{}),
        (prompt: "Inspect code", description: "Inspect", type: const {"custom": "future-agent"}),
      ]) {
        final target = buildMapper(activeSessionResolver: () => "root")
          ..beginTurn(sessionId: "root", messageId: "turn");
        completeForeground(target: target, sessionId: "root", toolCallId: "task");
        expect(
          target.map(
            taskRequest(
              toolCallId: "task",
              sessionId: null,
              subagentType: requestCase.type,
              prompt: requestCase.prompt,
              description: requestCase.description,
            ),
          ),
          isEmpty,
        );
        expect(target.map(validTaskRequest(toolCallId: "task", sessionId: null)), isEmpty);
      }

      final malformed = buildMapper(activeSessionResolver: () => "root")
        ..beginTurn(sessionId: "root", messageId: "turn");
      completeForeground(target: malformed, sessionId: "root", toolCallId: "task");
      expect(
        malformed.map(
          taskRequest(
            toolCallId: "task",
            sessionId: null,
            subagentType: "unspecified",
            prompt: "Inspect code",
            description: "Inspect",
          ),
        ),
        isEmpty,
      );
      expect(malformed.map(validTaskRequest(toolCallId: "task", sessionId: null)), hasLength(1));
    });

    test("explicit session wins, ambiguous Task ownership drops without active fallback", () {
      var fallbackCalls = 0;
      final target = buildMapper(
        activeSessionResolver: () {
          fallbackCalls++;
          return "root-b";
        },
      );
      target.beginTurn(sessionId: "root-a", messageId: "turn-a");
      target.beginTurn(sessionId: "root-b", messageId: "turn-b");
      completeForeground(target: target, sessionId: "root-a", toolCallId: "duplicate");
      completeForeground(target: target, sessionId: "root-b", toolCallId: "duplicate");

      expect(
        target.map(validTaskRequest(toolCallId: "duplicate", sessionId: null)),
        isEmpty,
        reason: "duplicate exact tool ids are ambiguous and must not fall back",
      );
      expect(fallbackCalls, 0);
      expect(
        target.map(validTaskRequest(toolCallId: "duplicate", sessionId: "wrong-root")),
        isEmpty,
        reason: "a valid explicit session wins even when it does not match correlation",
      );
      final first = target
          .map(validTaskRequest(toolCallId: "duplicate", sessionId: "root-a"))
          .whereType<BridgeSseMessagePartUpdated>()
          .single
          .part;
      final second = target
          .map(validTaskRequest(toolCallId: "duplicate", sessionId: "root-b"))
          .whereType<BridgeSseMessagePartUpdated>()
          .single
          .part;
      expect((first.sessionID, second.sessionID), ("root-a", "root-b"));

      expect(
        target.map(validTaskRequest(toolCallId: "not-found", sessionId: null)),
        isEmpty,
      );
      expect(fallbackCalls, 1, reason: "active-session fallback remains available only for genuine not-found");
    });

    test("next turn clears prior active and completed Tasks before current cancellation", () {
      final target = buildMapper(activeSessionResolver: () => "root");
      target.beginTurn(sessionId: "root", messageId: "turn-1");
      taskUpdate(
        target: target,
        sessionId: "root",
        toolCallId: "prior-active",
        status: "pending",
        starts: true,
        rawOutput: null,
      );
      completeForeground(target: target, sessionId: "root", toolCallId: "prior-completed");

      target.beginTurn(sessionId: "root", messageId: "turn-2");
      expect(
        target.mapPromptResult(sessionId: "root", stopReason: AcpStopReason.cancelled),
        isEmpty,
        reason: "prior active Task cannot be settled by the later turn",
      );
      expect(target.map(validTaskRequest(toolCallId: "prior-completed", sessionId: null)), isEmpty);
      taskUpdate(
        target: target,
        sessionId: "root",
        toolCallId: "prior-active",
        status: "failed",
        starts: false,
        rawOutput: null,
      );
      expect(target.map(validTaskRequest(toolCallId: "prior-active", sessionId: null)), isEmpty);

      final currentPart = taskUpdate(
        target: target,
        sessionId: "root",
        toolCallId: "current-active",
        status: "pending",
        starts: true,
        rawOutput: null,
      ).whereType<BridgeSseMessagePartUpdated>().single.part;
      final cancelled = target.mapPromptResult(
        sessionId: "root",
        stopReason: AcpStopReason.cancelled,
      );
      final cancelledPart = (cancelled.single as BridgeSseMessagePartUpdated).part as PluginMessagePartTool;
      expect(cancelledPart.id, currentPart.id);
      expect(cancelledPart.state.status, PluginToolStatus.cancelled);
      expect(
        target.mapPromptLifecycleFailure(sessionId: "root", failureMessage: "duplicate"),
        isEmpty,
      );
    });

    test("active count and unresolved residency stay independent through cleanup", () async {
      final taskTracker = CursorTaskTracker();
      final target = buildMapper(taskTracker: taskTracker);
      final changes = <void>[];
      final done = Completer<void>();
      taskTracker.residencyChanges.listen(changes.add, onDone: done.complete);

      target.beginTurn(sessionId: "root", messageId: "turn");
      for (final toolCallId in const ["active", "background"]) {
        taskUpdate(
          target: target,
          sessionId: "root",
          toolCallId: toolCallId,
          status: "pending",
          starts: true,
          rawOutput: null,
        );
      }
      expect(taskTracker.activeTaskCount(sessionId: "root"), 2);
      taskUpdate(
        target: target,
        sessionId: "root",
        toolCallId: "background",
        status: "completed",
        starts: false,
        rawOutput: {"isBackground": true},
      );
      expect(taskTracker.activeTaskCount(sessionId: "root"), 1);
      expect(taskTracker.hasUnresolvedBackgroundWork(sessionId: "root"), isTrue);
      expect(changes, hasLength(1));

      target.beginTurn(sessionId: "root", messageId: "later");
      expect(taskTracker.activeTaskCount(sessionId: "root"), 0);
      expect(taskTracker.hasUnresolvedBackgroundWork(sessionId: "root"), isTrue);
      taskTracker.forgetSession(sessionId: "other");
      expect(changes, hasLength(1));
      taskTracker.forgetSession(sessionId: "root");
      expect(taskTracker.requiresProcessResidency, isFalse);
      expect(changes, hasLength(2));

      await taskTracker.dispose();
      await done.future;
    });

    test("session and descendant deletion tombstones last until process reset", () {
      final taskTracker = CursorTaskTracker();
      final deletedMapper = buildMapper(taskTracker: taskTracker);
      AcpNotification lateTask({required String sessionId}) => AcpNotification(
        method: AcpMethods.sessionUpdate,
        params: {
          "sessionId": sessionId,
          "update": {
            "sessionUpdate": "tool_call",
            "toolCallId": "late-$sessionId",
            "title": "Task",
            "status": "pending",
            "rawInput": {"_toolName": "task"},
          },
        },
      );

      for (final sessionId in const ["s-deleted", "s-descendant"]) {
        deletedMapper.beginTurn(sessionId: sessionId, messageId: "turn-$sessionId");
        deletedMapper.forgetSession(sessionId);
        deletedMapper.map(lateTask(sessionId: sessionId));
        expect(taskTracker.hasInvocation(sessionId: sessionId, toolCallId: "late-$sessionId"), isFalse);
      }

      taskTracker.clear();
      deletedMapper.map(lateTask(sessionId: "s-deleted"));
      expect(taskTracker.hasInvocation(sessionId: "s-deleted", toolCallId: "late-s-deleted"), isTrue);
      taskTracker.clear();
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
