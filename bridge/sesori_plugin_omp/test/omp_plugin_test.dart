import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:omp_plugin/omp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("OmpPlugin", () {
    late FakeAcpProcess fake;
    late OmpPlugin plugin;
    late List<BridgeSseEvent> events;
    late AcpLaunchSpec launchSpec;

    setUp(() {
      fake = FakeAcpProcess();
      events = [];
      plugin = OmpPlugin(
        launchDirectory: "/repo",
        processFactory: (spec) async {
          launchSpec = spec;
          return fake;
        },
      );
      plugin.events.listen(events.add);
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    List<Map<String, dynamic>> frames(String method) =>
        fake.written.where((frame) => frame["method"] == method).toList(growable: false);

    Future<Map<String, dynamic>> waitForFrame(String method, {int count = 1}) async {
      for (var i = 0; i < 200; i++) {
        final matches = frames(method);
        if (matches.length >= count) return matches[count - 1];
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("OMP never wrote $count '$method' frame(s)");
    }

    void respond(Map<String, dynamic> frame, Map<String, dynamic> result) {
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
    }

    Future<void> connect({Map<String, dynamic>? capabilities}) async {
      final connecting = plugin.ensureConnected();
      final initialize = await waitForFrame(AcpMethods.initialize);
      respond(initialize, {
        "protocolVersion": 1,
        "agentCapabilities": capabilities ?? <String, dynamic>{},
        "authMethods": [
          {"id": "agent", "name": "Agent"},
        ],
      });
      final authenticate = await waitForFrame(AcpMethods.authenticate);
      expect(authenticate["params"], {"methodId": "agent"});
      respond(authenticate, const {});
      expect(await connecting, isTrue);
    }

    Future<PluginSession> create(String id) async {
      final expected = frames(AcpMethods.sessionNew).length + 1;
      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      final frame = await waitForFrame(AcpMethods.sessionNew, count: expected);
      respond(frame, {"sessionId": id});
      return await creating;
    }

    Future<void> send(String sessionId, String text) => plugin.sendPrompt(
      promptId: "prompt-1",
      sessionId: sessionId,
      parts: [PluginPromptPart.text(text: text)],
      variant: null,
      agent: null,
      model: null,
    );

    test("launches omp acp with inherited environment and local agent auth", () async {
      final connecting = plugin.ensureConnected();
      final initialize = await waitForFrame(AcpMethods.initialize);
      expect(launchSpec.command, "omp");
      expect(launchSpec.args, ["acp"]);
      expect(launchSpec.cwd, "/repo");
      expect(launchSpec.environment, isEmpty);
      final params = (initialize["params"] as Map).cast<String, dynamic>();
      expect((params["clientCapabilities"] as Map)["elicitation"], {
        "form": <String, dynamic>{},
      });

      respond(initialize, {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": [
          {"id": "agent", "name": "Agent"},
        ],
      });
      final authenticate = await waitForFrame(AcpMethods.authenticate);
      expect(authenticate["params"], {"methodId": "agent"});
      respond(authenticate, const {});
      expect(await connecting, isTrue);
    });

    test("uses OMP's per-session and fail-closed policies", () {
      expect(plugin.permitsDeviceCanvasHttpMcp, isTrue);
      expect(plugin.serializesPromptsProcessWide, isFalse);
      expect(plugin.cancelsActiveTurnForQueuedInput, isTrue);
      expect(plugin.failsTurnOnSelectionError, isTrue);
      expect(plugin.supportsFormElicitation, isTrue);
    });

    test("does not prompt after a partially applied model selection", () async {
      await connect();
      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      final createFrame = await waitForFrame(AcpMethods.sessionNew);
      respond(createFrame, {
        "sessionId": "session-1",
        "configOptions": [
          {
            "id": "model",
            "category": "model",
            "currentValue": "one/model",
            "options": const [
              {"value": "one/model", "name": "One"},
              {"value": "other/team/model", "name": "Other"},
            ],
          },
        ],
      });
      await creating;

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "session-1",
        parts: const [PluginPromptPart.text(text: "private prompt")],
        variant: null,
        agent: null,
        model: (providerID: "other", modelID: "other/team/model"),
      );
      final selection = await waitForFrame(AcpMethods.sessionSetConfigOption);
      expect(selection["params"], {
        "sessionId": "session-1",
        "configId": "model",
        "value": "other/team/model",
      });
      respond(selection, {
        "sessionId": "session-1",
        "configOptions": [
          {
            "id": "model",
            "category": "model",
            "currentValue": "one/model",
            "options": const [
              {"value": "one/model", "name": "One"},
              {"value": "other/team/model", "name": "Other"},
            ],
          },
        ],
      });
      for (var i = 0; i < 200 && events.whereType<BridgeSseSessionError>().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(frames(AcpMethods.sessionPrompt), isEmpty);
      expect(events.whereType<BridgeSseSessionError>(), hasLength(1));
    });

    test("uses ACP global and cwd session list forms", () async {
      await connect(
        capabilities: const {
          "sessionCapabilities": {
            "list": <String, dynamic>{},
          },
        },
      );
      final global = plugin.listAllSessions(knownDirectories: const {});
      final globalFrame = await waitForFrame(AcpMethods.sessionList);
      expect(globalFrame["params"], isEmpty);
      respond(globalFrame, {"sessions": <Object?>[]});
      final launchDirectoryFrame = await waitForFrame(AcpMethods.sessionList, count: 2);
      expect(launchDirectoryFrame["params"], {"cwd": "/repo"});
      respond(launchDirectoryFrame, {"sessions": <Object?>[]});
      expect(await global, isEmpty);

      final project = plugin.getSessions(projectId: "/repo", start: null, limit: null);
      final cwdFrame = await waitForFrame(AcpMethods.sessionList, count: 3);
      expect(cwdFrame["params"], {"cwd": "/repo"});
      respond(cwdFrame, {"sessions": <Object?>[]});
      expect(await project, isEmpty);
    });

    test("runs sessions concurrently and routes forms by explicit session id", () async {
      await connect();
      final first = await create("first");
      final second = await create("second");

      await send(first.id, "one");
      final firstPrompt = await waitForFrame(AcpMethods.sessionPrompt);
      await send(second.id, "two");
      final secondPrompt = await waitForFrame(AcpMethods.sessionPrompt, count: 2);
      expect((secondPrompt["params"] as Map)["sessionId"], second.id);

      fake.emit({
        "jsonrpc": "2.0",
        "id": 41,
        "method": AcpMethods.elicitationCreate,
        "params": {
          "sessionId": first.id,
          "mode": "form",
          "message": "Configure extension",
          "requestedSchema": {
            "type": "object",
            "properties": {
              "confirm": {"type": "boolean", "title": "Continue?"},
            },
          },
        },
      });
      await Future<void>.delayed(Duration.zero);
      final questions = await plugin.getPendingQuestions(sessionId: first.id);
      expect(questions, hasLength(1));
      expect(await plugin.getPendingQuestions(sessionId: second.id), isEmpty);
      await plugin.replyToQuestion(
        questionId: questions.single.id,
        sessionId: first.id,
        answers: const [
          ["Yes"],
        ],
      );
      expect(fake.written.where((frame) => frame["id"] == 41).single["result"], {
        "action": "accept",
        "content": {"confirm": true},
      });

      respond(firstPrompt, {"stopReason": "end_turn"});
      respond(secondPrompt, {"stopReason": "end_turn"});
    });

    test("a prompt queued on the active session cancels that turn before dispatch", () async {
      await connect();
      final session = await create("session");

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: session.id,
        parts: const [PluginPromptPart.text(text: "keep searching")],
        variant: null,
        agent: null,
        model: null,
      );
      final firstPrompt = await waitForFrame(AcpMethods.sessionPrompt);

      await plugin.sendPrompt(
        promptId: "prompt-2",
        sessionId: session.id,
        parts: const [PluginPromptPart.text(text: "stop")],
        variant: null,
        agent: null,
        model: null,
      );
      final cancel = await waitForFrame(AcpMethods.sessionCancel);
      expect(cancel["params"], {"sessionId": session.id});
      expect(frames(AcpMethods.sessionPrompt), hasLength(1));
      expect((await plugin.getQueuedPrompts(sessionId: session.id)).single.id, "prompt-2");

      respond(firstPrompt, {"stopReason": "cancelled"});
      final replacement = await waitForFrame(AcpMethods.sessionPrompt, count: 2);
      expect((replacement["params"] as Map)["sessionId"], session.id);
      expect(await plugin.getQueuedPrompts(sessionId: session.id), isEmpty);
      expect(
        events
            .whereType<BridgeSseMessageUpdated>()
            .singleWhere((event) => event.info["promptId"] == "prompt-2")
            .info["role"],
        "user",
      );
      respond(replacement, {"stopReason": "end_turn"});
    });

    test("maps live reasoning, tools, images, and final text", () async {
      await connect();
      final session = await create("session-1");
      await send(session.id, "inspect it");
      final prompt = await waitForFrame(AcpMethods.sessionPrompt);
      events.clear();

      for (final update in <Map<String, dynamic>>[
        {
          "sessionUpdate": "agent_thought_chunk",
          "content": {"type": "text", "text": "Thinking"},
        },
        {
          "sessionUpdate": "tool_call",
          "toolCallId": "tool-1",
          "kind": "read",
          "status": "completed",
          "content": [
            {
              "type": "content",
              "content": {"type": "text", "text": "tool output"},
            },
          ],
        },
        {
          "sessionUpdate": "agent_message_chunk",
          "content": {
            "type": "image",
            "data": "AA==",
            "mimeType": "image/png",
            "uri": "file:///private/result.png",
          },
        },
        {
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": "Finished"},
        },
      ]) {
        fake.emit({
          "jsonrpc": "2.0",
          "method": AcpMethods.sessionUpdate,
          "params": {"sessionId": session.id, "update": update},
        });
      }
      respond(prompt, {"stopReason": "end_turn"});
      for (var i = 0; i < 200 && events.whereType<BridgeSseSessionIdle>().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final parts = events.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part).toList();
      expect(
        parts.map((part) => part.type),
        containsAll(<PluginMessagePartType>[
          PluginMessagePartType.reasoning,
          PluginMessagePartType.tool,
          PluginMessagePartType.file,
          PluginMessagePartType.text,
        ]),
      );
      final finalizedReasoning = parts.indexWhere(
        (part) => part is PluginMessagePartReasoning && part.text == "Thinking",
      );
      final tool = parts.indexWhere((part) => part.type == PluginMessagePartType.tool);
      expect(finalizedReasoning, isNonNegative);
      expect(finalizedReasoning, lessThan(tool));
      expect(parts.whereType<PluginMessagePartTool>().single.state.output, "tool output");
      final image = parts.whereType<PluginMessagePartFile>().single.attachment;
      expect(image, isA<PluginMessageAttachmentInlineImage>());
      expect(image.toString(), isNot(contains("/private/")));
      expect(parts.whereType<PluginMessagePartText>().last.text, "Finished");
    });

    test("replays stored OMP history through session load", () async {
      plugin.primeSessionDirectory(sessionId: "stored", directory: "/repo");
      final loading = plugin.getSessionMessages("stored");
      final initialize = await waitForFrame(AcpMethods.initialize);
      respond(initialize, {
        "protocolVersion": 1,
        "agentCapabilities": {"loadSession": true},
        "authMethods": [
          {"id": "agent", "name": "Agent"},
        ],
      });
      final authenticate = await waitForFrame(AcpMethods.authenticate);
      respond(authenticate, const {});
      final load = await waitForFrame(AcpMethods.sessionLoad);
      expect(load["params"], {
        "sessionId": "stored",
        "cwd": "/repo",
        "mcpServers": <Object?>[],
      });
      for (final update in <Map<String, dynamic>>[
        {
          "sessionUpdate": "user_message_chunk",
          "content": {"type": "text", "text": "Question"},
        },
        {
          "sessionUpdate": "agent_message_chunk",
          "content": [
            {"type": "text", "text": "Answer"},
            {
              "type": "image",
              "data": "AQ==",
              "mimeType": "image/webp",
              "uri": "file:///private/history.webp",
            },
          ],
        },
      ]) {
        fake.emit({
          "jsonrpc": "2.0",
          "method": AcpMethods.sessionUpdate,
          "params": {"sessionId": "stored", "update": update},
        });
      }
      respond(load, {"sessionId": "stored"});

      final messages = await loading;
      expect(messages, hasLength(2));
      expect((messages.first.parts.single as PluginMessagePartText).text, "Question");
      expect(messages.last.parts.map((part) => part.type), [
        PluginMessagePartType.text,
        PluginMessagePartType.file,
      ]);
      final image =
          (messages.last.parts.last as PluginMessagePartFile).attachment as PluginMessageAttachmentInlineImage;
      expect(image.base64, "AQ==");
      expect(image.filename, "history.webp");
      expect(image.toString(), isNot(contains("/private/")));
    });

    test("resumes a prior-process session before prompting", () async {
      await connect(
        capabilities: const {
          "loadSession": false,
          "sessionCapabilities": {
            "resume": <String, dynamic>{},
          },
        },
      );
      plugin.primeSessionDirectory(sessionId: "stored", directory: "/repo");
      await send("stored", "continue");
      final resume = await waitForFrame(AcpMethods.sessionResume);
      expect(resume["params"], {
        "sessionId": "stored",
        "cwd": "/repo",
        "mcpServers": <Object?>[],
      });
      respond(resume, {"sessionId": "stored"});
      final prompt = await waitForFrame(AcpMethods.sessionPrompt);
      respond(prompt, {"stopReason": "end_turn"});
      expect(frames(AcpMethods.sessionLoad), isEmpty);
    });

    test("routes configured permissions and returns the selected outcome", () async {
      await connect();
      final session = await create("session-1");
      await send(session.id, "run it");
      final prompt = await waitForFrame(AcpMethods.sessionPrompt);

      fake.emit({
        "jsonrpc": "2.0",
        "id": 51,
        "method": AcpMethods.sessionRequestPermission,
        "params": {
          "sessionId": session.id,
          "toolCall": {
            "toolCallId": "tool-1",
            "title": "Run command",
            "kind": "execute",
          },
          "options": [
            {"optionId": "once", "name": "Allow", "kind": "allow_once"},
            {"optionId": "reject", "name": "Reject", "kind": "reject_once"},
          ],
        },
      });
      for (var i = 0; i < 200 && events.whereType<BridgeSsePermissionAsked>().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final permission = events.whereType<BridgeSsePermissionAsked>().single;
      expect(permission.sessionID, session.id);
      await plugin.replyToPermission(
        requestId: permission.requestID,
        sessionId: session.id,
        reply: PluginPermissionReply.once,
      );
      expect(fake.written.where((frame) => frame["id"] == 51).single["result"], {
        "outcome": {"outcome": "selected", "optionId": "once"},
      });
      respond(prompt, {"stopReason": "end_turn"});
    });

    test("settles cancellation before closing a resident session", () async {
      await connect(
        capabilities: const {
          "sessionCapabilities": {
            "close": <String, dynamic>{},
          },
        },
      );
      final session = await create("session-1");
      await send(session.id, "long turn");
      final prompt = await waitForFrame(AcpMethods.sessionPrompt);

      final deleting = plugin.deleteSession(session.id);
      await waitForFrame(AcpMethods.sessionCancel);
      expect(frames(AcpMethods.sessionClose), isEmpty);
      respond(prompt, {"stopReason": "cancelled"});
      final close = await waitForFrame(AcpMethods.sessionClose);
      respond(close, const {});
      await deleting;
      expect(await plugin.getSessionStatuses(), isNot(contains(session.id)));
    });

    test("reconnects after process exit and disposes the replacement process", () async {
      await plugin.dispose();
      await fake.close();
      final processes = <FakeAcpProcess>[];
      final specs = <AcpLaunchSpec>[];
      plugin = OmpPlugin(
        launchDirectory: "/repo",
        processFactory: (spec) async {
          specs.add(spec);
          final process = FakeAcpProcess();
          processes.add(process);
          fake = process;
          return process;
        },
      );
      plugin.events.listen(events.add);

      await connect();
      processes.single.exit(1);
      await Future<void>.delayed(Duration.zero);
      await plugin.resetConnectionAfterExit();
      final reconnecting = plugin.ensureConnected();
      final initialize = await waitForFrame(AcpMethods.initialize);
      respond(initialize, {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": [
          {"id": "agent", "name": "Agent"},
        ],
      });
      final authenticate = await waitForFrame(AcpMethods.authenticate);
      respond(authenticate, const {});
      expect(await reconnecting, isTrue);
      expect(processes, hasLength(2));
      expect(specs.map((spec) => spec.command), everyElement("omp"));
      expect(specs.map((spec) => spec.args), everyElement(["acp"]));

      await plugin.dispose();
      expect(processes.last.exitCode, completion(-15));
      for (final process in processes) {
        await process.close();
      }
    });

    test("redacts missing-model failures and provides local login guidance", () async {
      await connect();
      final session = await create("session-1");
      await send(session.id, "private prompt");
      final prompt = await waitForFrame(AcpMethods.sessionPrompt);
      fake.emit({
        "jsonrpc": "2.0",
        "id": prompt["id"],
        "error": {
          "code": -32603,
          "message": "Internal error",
          "data": {
            "details": "No model selected. Database: /Users/private/.omp/models.db",
          },
        },
      });
      for (var i = 0; i < 200 && events.whereType<BridgeSseTuiToastShow>().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(events.whereType<BridgeSseSessionError>(), hasLength(1));
      final toast = events.whereType<BridgeSseTuiToastShow>().single;
      expect(toast.sessionID, session.id);
      expect(toast.message, contains("run /login"));
      expect(toast.message, isNot(contains("/Users/private")));
      expect(toast.message, isNot(contains("private prompt")));
    });
  });
}
