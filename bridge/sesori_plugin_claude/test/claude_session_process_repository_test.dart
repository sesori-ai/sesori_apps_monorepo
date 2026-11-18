import "dart:async";
import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/claude_stream_client_test_factory.dart";
import "support/fake_claude_process.dart";
import "support/fake_sesori_mcp_access.dart";

void main() {
  group("ClaudeSessionProcessRepository", () {
    late _ProcessHarness harness;
    late ClaudeSessionProcessRepository repository;

    setUp(() {
      harness = _ProcessHarness();
      repository = ClaudeSessionProcessRepository(
        supportsMcpAuthentication: true,
        processFactory: harness.spawn,
        binaryPath: "claude",
        transcriptsDirectory: "/tmp/sesori/transcripts",
        uploadsDirectory: "/tmp/sesori/uploads",
        sesoriMcp: FakeSesoriMcpAccess(),
        sesoriMcpConfig: ClaudeSesoriMcpConfigApi(directory: "/tmp/sesori/state"),
        environment: const {},
      );
    });

    tearDown(() async {
      await repository.dispose();
      await harness.close();
    });

    test("inventory reads do not create or resume a process", () async {
      final result = await repository.getMcpInventory(scope: const PluginMcpSessionScope(sessionId: testSessionId));
      expect(
        result,
        isA<PluginMcpInventoryUnavailable>().having(
          (value) => value.reason,
          "reason",
          PluginMcpInventoryUnavailableReason.liveSessionRequired,
        ),
      );
      final unsupported = await repository.getMcpInventory(scope: const PluginMcpHarnessScope());
      expect(
        unsupported,
        isA<PluginMcpInventoryUnavailable>().having(
          (value) => value.reason,
          "reason",
          PluginMcpInventoryUnavailableReason.unsupportedScope,
        ),
      );
      expect(harness.specs, isEmpty);
    });

    test("MCP controls never create a session and reject unsupported scope", () async {
      for (final scope in [const PluginMcpHarnessScope(), const PluginMcpSessionScope(sessionId: testSessionId)]) {
        final result = await repository.executeMcpServerAction(
          target: PluginMcpServerTarget(scope: scope, serverKey: "fixture"),
          action: PluginMcpServerAction.reconnect,
        );
        expect(result, isA<PluginMcpActionUnavailable>());
      }
      expect(harness.specs, isEmpty);
    });

    test("authentication context never starts a resident and rejects unsupported scope", () async {
      for (final (scope, reason) in [
        (const PluginMcpHarnessScope(), PluginMcpAuthenticationUnavailableReason.unsupportedScope),
        (
          const PluginMcpSessionScope(sessionId: testSessionId),
          PluginMcpAuthenticationUnavailableReason.liveSessionRequired,
        ),
      ]) {
        await expectLater(
          repository.resolveMcpAuthenticationContext(
            target: PluginMcpServerTarget(scope: scope, serverKey: "fixture"),
          ),
          throwsA(isA<PluginMcpAuthenticationUnavailableException>().having((e) => e.reason, "reason", reason)),
        );
      }
      expect(harness.specs, isEmpty);
    });

    for (final (nativeScope, url, reason) in [
      ("dynamic", "https://fixture.example/mcp", PluginMcpAuthenticationUnavailableReason.nativeConfigurationRequired),
      (null, "https://fixture.example/mcp", PluginMcpAuthenticationUnavailableReason.nativeConfigurationRequired),
      ("local", null, PluginMcpAuthenticationUnavailableReason.notSupported),
    ]) {
      test("authentication rejects unresolved CLI config $nativeScope/$url", () async {
        await _ensure(repository, createNew: true);
        final result = repository.resolveMcpAuthenticationContext(
          target: const PluginMcpServerTarget(
            scope: PluginMcpSessionScope(sessionId: testSessionId),
            serverKey: "fixture",
          ),
        );
        final rejected = expectLater(
          result,
          throwsA(isA<PluginMcpAuthenticationUnavailableException>().having((e) => e.reason, "reason", reason)),
        );
        await pump();
        final process = harness.processes.single;
        final request = process.written.lastWhere((f) => f["type"] == "control_request");
        process.emitControlResponse(
          requestId: request.field<String>("request_id"),
          payload: {
            "mcpServers": [
              {
                "name": "fixture",
                "status": "needs-auth",
                "scope": nativeScope,
                "config": {"type": url == null ? "stdio" : "http", "url": url},
              },
            ],
          },
        );
        await rejected;
        expect(harness.specs, hasLength(1));
      });
    }

    test("authentication binds the exact native server and resident directory", () async {
      await _ensure(repository, createNew: true);
      final result = repository.resolveMcpAuthenticationContext(
        target: const PluginMcpServerTarget(
          scope: PluginMcpSessionScope(sessionId: testSessionId),
          serverKey: "fixture",
        ),
      );
      await pump();
      final process = harness.processes.single;
      final request = process.written.lastWhere((f) => f["type"] == "control_request");
      process.emitControlResponse(
        requestId: request.field<String>("request_id"),
        payload: {
          "mcpServers": [
            {
              "name": "fixture",
              "status": "needs-auth",
              "scope": "local",
              "config": {"type": "http", "url": "https://fixture.example/mcp"},
            },
          ],
        },
      );
      final context = await result;
      expect(context.serverName, "fixture");
      expect(context.workingDirectory, harness.specs.single.workingDirectory);
      expect(harness.specs, hasLength(1));
    });

    for (final action in PluginMcpServerAction.values) {
      test("MCP ${action.name} controls exactly the existing resident server", () async {
        await _ensure(repository, createNew: true);
        final process = harness.processes.single;
        final result = repository.executeMcpServerAction(
          target: const PluginMcpServerTarget(
            scope: PluginMcpSessionScope(sessionId: testSessionId),
            serverKey: "fixture",
          ),
          action: action,
        );
        await pump();
        var request = process.written.lastWhere((frame) => frame["type"] == "control_request");
        expect(request["request"], {"subtype": "mcp_status"});
        process.emitControlResponse(
          requestId: request.field<String>("request_id"),
          payload: {
            "mcpServers": [
              {"name": "fixture", "status": "connected"},
            ],
          },
        );
        await pump();
        request = process.written.lastWhere((frame) => frame["type"] == "control_request");
        expect(request["request"], switch (action) {
          PluginMcpServerAction.reconnect => {"subtype": "mcp_reconnect", "serverName": "fixture"},
          PluginMcpServerAction.enable => {"subtype": "mcp_toggle", "serverName": "fixture", "enabled": true},
          PluginMcpServerAction.disable => {"subtype": "mcp_toggle", "serverName": "fixture", "enabled": false},
        });
        process.emitControlResponse(requestId: request.field<String>("request_id"), payload: {});
        expect(
          await result,
          isA<PluginMcpActionCompleted>().having(
            (value) => value.effectScope,
            "effect",
            PluginMcpActionEffectScope.session,
          ),
        );
        expect(harness.specs, hasLength(1));
      });
    }

    test("MCP controls reject a vanished target before sending a mutation", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final result = repository.executeMcpServerAction(
        target: const PluginMcpServerTarget(
          scope: PluginMcpSessionScope(sessionId: testSessionId),
          serverKey: "missing",
        ),
        action: PluginMcpServerAction.enable,
      );
      await pump();
      final request = process.written.lastWhere((frame) => frame["type"] == "control_request");
      process.emitControlResponse(requestId: request.field<String>("request_id"), payload: {"mcpServers": []});
      expect(
        await result,
        isA<PluginMcpActionUnavailable>().having(
          (r) => r.reason,
          "reason",
          PluginMcpActionUnavailableReason.targetNotFound,
        ),
      );
      expect(process.written.where((f) => (f["request"] as Map? ?? {})["subtype"] == "mcp_toggle"), isEmpty);
    });

    test("malformed MCP status fails reads and controls without mutating or resuming", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      for (final control in [false, true]) {
        final Future<Object> result = control
            ? repository.executeMcpServerAction(
                target: const PluginMcpServerTarget(
                  scope: PluginMcpSessionScope(sessionId: testSessionId),
                  serverKey: "fixture",
                ),
                action: PluginMcpServerAction.enable,
              )
            : repository.getMcpInventory(scope: const PluginMcpSessionScope(sessionId: testSessionId));
        await pump();
        final request = process.written.lastWhere((frame) => frame["type"] == "control_request");
        process.emitControlResponse(requestId: request.field<String>("request_id"), payload: {"renamedServers": []});
        final failed = await result;
        final (cause, stackTrace) = switch (failed) {
          PluginMcpActionFailed(:final cause, :final causeStackTrace) => (cause, causeStackTrace),
          PluginMcpInventoryReadFailed(:final cause, :final causeStackTrace) => (cause, causeStackTrace),
          _ => throw StateError("Expected a typed failure"),
        };
        expect(cause, isA<ClaudeMcpStatusTypeException>().having((e) => e.innerError, "innerError", isA<TypeError>()));
        expect(stackTrace.toString(), contains("ClaudeMcpStatusDtoFromJson"));
        expect(process.written.where((f) => (f["request"] as Map? ?? {})["subtype"] == "mcp_toggle"), isEmpty);
      }
      expect(harness.specs, hasLength(1));
    });

    test("MCP control teardown retains the typed cause and does not resume", () async {
      await _ensure(repository, createNew: true);
      final result = repository.executeMcpServerAction(
        target: const PluginMcpServerTarget(
          scope: PluginMcpSessionScope(sessionId: testSessionId),
          serverKey: "fixture",
        ),
        action: PluginMcpServerAction.reconnect,
      );
      await pump();
      await repository.teardown(sessionId: testSessionId);
      expect(await result, isA<PluginMcpActionFailed>().having((r) => r.cause, "cause", isA<ClaudeControlException>()));
      expect(harness.specs, hasLength(1));
    });

    test("inventory reads status through the resident process control channel", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final result = repository.getMcpInventory(scope: const PluginMcpSessionScope(sessionId: testSessionId));
      await pump();
      final request = process.written.lastWhere((frame) => frame["type"] == "control_request");
      expect(request["request"], {"subtype": "mcp_status"});
      process.emitControlResponse(
        requestId: request.field<String>("request_id"),
        payload: {
          "mcpServers": [
            {"name": "fixture", "status": "connected", "tools": <Map<String, dynamic>>[]},
          ],
        },
      );
      expect((await result as PluginMcpInventorySnapshot).entries, hasLength(1));
      expect(harness.specs, hasLength(1));
    });

    test("side questions need a resident process and never start one", () async {
      await expectLater(
        repository.sendSideQuestion(sessionId: testSessionId, question: "Why?", history: const []),
        throwsStateError,
      );
      expect(harness.specs, isEmpty);
    });

    test("side questions send the history and map the answer", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final answer = repository.sendSideQuestion(
        sessionId: testSessionId,
        question: "And now?",
        history: const [PluginSideExchange(question: "Why?", answer: "Because.")],
      );
      await pump();
      final request = process.written.lastWhere((frame) => frame["type"] == "control_request");
      expect(request["request"], {
        "subtype": "side_question",
        "question": "And now?",
        "history": [
          {"question": "Why?", "response": "Because."},
        ],
      });
      process.emitControlResponse(
        requestId: request.field<String>("request_id"),
        payload: {"response": "Still because.", "synthetic": false},
      );

      expect(await answer, isA<PluginSideAnswered>().having((a) => a.text, "text", "Still because."));
      expect(harness.specs, hasLength(1));
    });

    group("a side question asked while a turn streams", () {
      const reply = "1. The ocean covers most of the planet.\n2. It holds most of its life.";

      // The frames as 2.1.325 sent them (anthropics/claude-code#110490): the
      // turn's result, then the side question's reply, in one stdout chunk.
      Future<PluginSideAnswer> ask({required String sideReply}) async {
        await _ensure(repository, createNew: true);
        final process = harness.processes.single;
        final answer = repository.sendSideQuestion(
          sessionId: testSessionId,
          question: "What's 2+2?",
          history: const [],
        );
        await pump();
        final requestId = process.written
            .lastWhere((frame) => frame["type"] == "control_request")
            .field<String>(
              "request_id",
            );
        final frames = [
          {"type": "result", "subtype": "success", "is_error": false, "result": reply, "session_id": testSessionId},
          {
            "type": "control_response",
            "response": {
              "subtype": "success",
              "request_id": requestId,
              "response": {"response": sideReply, "synthetic": false},
            },
          },
        ];
        process.emitRaw(utf8.encode(frames.map((frame) => "${jsonEncode(frame)}\n").join()));
        return await answer;
      }

      test("is refused when it comes back as the turn's reply", () async {
        expect(
          await ask(sideReply: reply),
          isA<PluginSideRefused>().having((r) => r.reason, "reason", PluginSideRefusal.repeatedRunningReply),
        );
      });

      test("is answered when its reply is its own", () async {
        expect(await ask(sideReply: "4"), isA<PluginSideAnswered>().having((a) => a.text, "text", "4"));
      });
    });

    test("a CLI without the side-question handler asks for an update", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final answer = repository.sendSideQuestion(sessionId: testSessionId, question: "Why?", history: const []);
      await pump();
      process.emitControlError(
        requestId: process.written.last.field<String>("request_id"),
        error: "Unsupported control request subtype: side_question",
      );

      expect(
        await answer,
        isA<PluginSideRefused>().having((r) => r.reason, "reason", PluginSideRefusal.harnessUpdateRequired),
      );
    });

    test("inventory control rejection retains the original diagnostic cause", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final result = repository.getMcpInventory(scope: const PluginMcpSessionScope(sessionId: testSessionId));
      await pump();
      final request = process.written.lastWhere((frame) => frame["type"] == "control_request");
      process.emitControlError(requestId: request.field<String>("request_id"), error: "fixture native rejection");
      final failed = await result as PluginMcpInventoryReadFailed;
      expect(
        failed.cause,
        isA<ClaudeControlException>().having((error) => error.message, "message", "fixture native rejection"),
      );
      expect(failed.causeStackTrace.toString(), isNotEmpty);
      expect(harness.specs, hasLength(1));
    });

    test("process exit during an inventory read returns a read failure without resuming", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final result = repository.getMcpInventory(scope: const PluginMcpSessionScope(sessionId: testSessionId));
      await pump();
      process.exit(1);
      expect(
        await result,
        isA<PluginMcpInventoryReadFailed>().having((value) => value.cause, "cause", isA<ClaudeControlException>()),
      );
      expect(harness.specs, hasLength(1));
    });

    test("teardown during inventory reads returns a typed failure", () async {
      await _ensure(repository, createNew: true);
      final result = repository.getMcpInventory(scope: const PluginMcpSessionScope(sessionId: testSessionId));
      await pump();
      await repository.teardown(sessionId: testSessionId);
      expect(
        await result,
        isA<PluginMcpInventoryReadFailed>().having(
          (value) => value.cause,
          "cause",
          isA<ClaudeControlException>().having(
            (error) => error.message,
            "message",
            "ClaudeStreamClient disposed",
          ),
        ),
      );
      expect(harness.specs, hasLength(1));
    });

    test("creates first process and resumes after an accepted turn", () async {
      await _ensure(repository, createNew: true);
      expect(harness.specs.single.launch, isA<ClaudeNewSession>());

      final turn = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [PluginPromptPart.text(text: "hello")],
        promptId: null,
      );
      final written = await waitForFrame(harness.processes.single, "user");
      expect(turn.messageId, written["uuid"]);
      harness.processes.single.emit(_result());
      expect(await turn.outcome, isA<ClaudeTurnCompleted>());

      await repository.teardown(sessionId: testSessionId);
      await _ensure(repository, createNew: true);

      expect(harness.specs, hasLength(2));
      expect(harness.specs.last.launch, isA<ClaudeResumedSession>());
    });

    test("gives every session launch its own bound Sesori token and probes none", () async {
      final access = FakeSesoriMcpAccess(enabled: true);
      final state = await Directory.systemTemp.createTemp("claude-sesori-mcp-");
      addTearDown(() => state.delete(recursive: true));
      final injecting = ClaudeSessionProcessRepository(
        supportsMcpAuthentication: true,
        processFactory: harness.spawn,
        binaryPath: "claude",
        transcriptsDirectory: "/tmp/sesori/transcripts",
        uploadsDirectory: "/tmp/sesori/uploads",
        sesoriMcp: access,
        sesoriMcpConfig: ClaudeSesoriMcpConfigApi(directory: state.path),
        environment: const {},
      );
      addTearDown(injecting.dispose);

      await _ensure(injecting, createNew: true);
      await injecting.teardown(sessionId: testSessionId);
      await _ensure(injecting, createNew: false);
      await injecting.ensureResident(
        sessionId: otherTestSessionId,
        directory: "/tmp/project",
        createNew: true,
        purpose: ClaudeProcessPurpose.catalogProbe,
        model: null,
        effort: null,
        permissionMode: null,
        fastMode: false,
        allowedTools: const [],
      );

      expect(access.minted, hasLength(2));
      expect(access.bound.map((binding) => binding.backendSessionId), [testSessionId, testSessionId]);
      expect(access.bound.map((binding) => binding.launch), access.minted);
      expect(harness.specs.map((spec) => spec.sesoriMcp?.serverName), [
        sesoriMcpServerName,
        sesoriMcpServerName,
        isNull,
      ]);
      expect(harness.sesoriMcpConfigs, [contains('"Bearer token-1"'), contains('"Bearer token-2"')]);
      // The token lives on disk only until the handshake.
      expect(state.listSync(), isEmpty);
    });

    test("settles steering input with the result after its replay", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final first = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [PluginPromptPart.text(text: "first")],
        promptId: "prompt-first",
      );
      final second = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [PluginPromptPart.text(text: "second")],
        promptId: "prompt-second",
      );
      await _waitForUserFrames(process, 2);
      var secondSettled = false;
      unawaited(second.outcome.then((_) => secondSettled = true));

      process.emit(_replayOf(_userFrames(process)[0], uuid: "replay-first"));
      process.emit(_result());
      expect(await first.outcome, isA<ClaudeTurnCompleted>());
      await pump();
      expect(secondSettled, isFalse);

      process.emit(_replayOf(_userFrames(process)[1], uuid: "replay-second"));
      process.emit(_result());
      expect(await second.outcome, isA<ClaudeTurnCompleted>());
    });

    test("one result settles steering messages absorbed into the active turn", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final replayPromptIds = <String?>[];
      final subscription = repository.events
          .where((event) => event is ClaudeSessionProcessMessage)
          .cast<ClaudeSessionProcessMessage>()
          .listen((event) {
            if (event.message case ClaudeUserMessage(isReplay: true)) {
              replayPromptIds.add(event.promptId);
            }
          });
      final first = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [PluginPromptPart.text(text: "first")],
        promptId: "prompt-first",
      );
      final second = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [PluginPromptPart.text(text: "second")],
        promptId: "prompt-second",
      );
      await _waitForUserFrames(process, 2);

      process.emit(_internalReplay());
      process.emit(_replayOf(_userFrames(process)[0], uuid: "replay-first"));
      process.emit(_replayOf(_userFrames(process)[1], uuid: "replay-second"));
      process.emit(_result());

      expect(await first.outcome, isA<ClaudeTurnCompleted>());
      expect(await second.outcome, isA<ClaudeTurnCompleted>());
      await pump();
      expect(replayPromptIds, [null, "prompt-first", "prompt-second"]);
      await subscription.cancel();
    });

    test("correlates an unmarked re-encoded image echo with its prompt", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final promptIds = <String?>[];
      final subscription = repository.events
          .where((event) => event is ClaudeSessionProcessMessage)
          .cast<ClaudeSessionProcessMessage>()
          .where((event) => event.message is ClaudeUserMessage)
          .listen((event) => promptIds.add(event.promptId));
      final turn = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [
          PluginPromptPart.text(text: "inspect this"),
          PluginPromptPart.fileData(mime: "image/png", base64: "iVBORw0KGgo=", filename: "image.png"),
        ],
        promptId: "prompt-image",
      );
      final written = await waitForFrame(process, "user");

      process.emit(_reencodedImageEcho(written: written, uuid: "echo-image"));
      await pump();

      expect(promptIds, ["prompt-image"]);
      process.emit(_result());
      expect(await turn.outcome, isA<ClaudeTurnCompleted>());
      await subscription.cancel();
    });

    test("correlates a replay that echoes a text prompt as string content", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final promptIds = <String?>[];
      final subscription = repository.events
          .where((event) => event is ClaudeSessionProcessMessage)
          .cast<ClaudeSessionProcessMessage>()
          .where((event) => event.message is ClaudeUserMessage)
          .listen((event) => promptIds.add(event.promptId));
      const text = "/Users/dev/Downloads/clip.mov convert this to mp4";
      final turn = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [PluginPromptPart.text(text: text)],
        promptId: "prompt-path",
      );
      final written = await waitForFrame(process, "user");

      process.emit({
        ..._replayOf(written, uuid: "replay-path"),
        "message": {"role": "user", "content": text},
      });
      await pump();

      expect(promptIds, ["prompt-path"]);
      process.emit(_result());
      expect(await turn.outcome, isA<ClaudeTurnCompleted>());
      await subscription.cancel();
    });

    test("does not correlate an unmarked text user message", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final promptIds = <String?>[];
      final subscription = repository.events
          .where((event) => event is ClaudeSessionProcessMessage)
          .cast<ClaudeSessionProcessMessage>()
          .where((event) => event.message is ClaudeUserMessage)
          .listen((event) => promptIds.add(event.promptId));
      final turn = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [PluginPromptPart.text(text: "ordinary text")],
        promptId: "prompt-text",
      );
      final written = await waitForFrame(process, "user");

      process.emit({...written, "uuid": "unmarked-text"});
      await pump();

      expect(promptIds, [null]);
      process.emit(_result());
      expect(await turn.outcome, isA<ClaudeTurnCompleted>());
      await subscription.cancel();
    });

    test("a late replay does not make an idle process look active", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final first = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [PluginPromptPart.text(text: "first")],
        promptId: "prompt-first",
      );
      final firstFrame = await waitForFrame(process, "user");
      process.emit(_result());
      await first.outcome;

      process.emit(_replayOf(firstFrame, uuid: "late-first"));
      final second = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [PluginPromptPart.text(text: "second")],
        promptId: "prompt-second",
      );
      process.emit(_result());

      expect(await second.outcome, isA<ClaudeTurnCompleted>());
    });

    test("restores idle tracking after a failed first stdin write", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      process.failNextStdinWrite();

      expect(
        () => repository.sendTurn(
          sessionId: testSessionId,
          echoAtOnce: false,
          parts: const [PluginPromptPart.text(text: "fails")],
          promptId: "prompt-fails",
        ),
        throwsA(isA<ClaudeControlException>()),
      );
      final next = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [PluginPromptPart.text(text: "next")],
        promptId: "prompt-next",
      );
      await waitForFrame(process, "user");
      process.emit(_result());

      expect(
        await next.outcome.timeout(const Duration(milliseconds: 100)),
        isA<ClaudeTurnCompleted>(),
      );
    });

    test("retries a new launch when no first turn was accepted", () async {
      await _ensure(repository, createNew: true);
      await repository.teardown(sessionId: testSessionId);

      await _ensure(repository, createNew: true);

      expect(harness.specs, hasLength(2));
      expect(harness.specs.last.launch, isA<ClaudeNewSession>());
    });

    test("classifies a successful result with permission denials as a completed transport turn", () async {
      await _ensure(repository, createNew: true);
      final turn = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [PluginPromptPart.text(text: "hello")],
        promptId: null,
      );
      await waitForFrame(harness.processes.single, "user");
      harness.processes.single.emit({
        ..._result(),
        "permission_denials": [
          {"tool_name": "Write", "tool_use_id": "toolu-1"},
        ],
      });

      expect(await turn.outcome, isA<ClaudeTurnCompleted>());
    });

    test("classifies an unexpected process exit as a failed turn", () async {
      await _ensure(repository, createNew: true);
      final exits = <ClaudeSessionProcessExited>[];
      final subscription = repository.events
          .where((event) => event is ClaudeSessionProcessExited)
          .cast<ClaudeSessionProcessExited>()
          .listen(exits.add);

      final turn = repository.sendTurn(
        sessionId: testSessionId,
        echoAtOnce: false,
        parts: const [PluginPromptPart.text(text: "hello")],
        promptId: null,
      );
      await waitForFrame(harness.processes.single, "user");
      harness.processes.single.exit(1);

      expect(await turn.outcome, isA<ClaudeTurnFailed>());
      await pump();
      expect(exits.single.sessionId, testSessionId);
      expect(exits.single.interrupted, isFalse);
      await subscription.cancel();
    });

    test("drops unsupported inline data instead of sending it as an image", () async {
      await _ensure(repository, createNew: true);

      expect(
        () => repository.sendTurn(
          sessionId: testSessionId,
          echoAtOnce: false,
          parts: const [PluginPromptPart.fileData(mime: "application/pdf", base64: "secret", filename: "a.pdf")],
          promptId: null,
        ),
        throwsStateError,
      );
      expect(harness.processes.single.written.where((frame) => frame["type"] == "user"), isEmpty);
    });

    test("does not retain a process that connects after disposal", () async {
      final gate = Completer<void>();
      harness.beforeInitialize = gate.future;
      final residency = _ensure(repository, createNew: true);
      await pump();

      final disposal = repository.dispose();

      await expectLater(residency, throwsA(isA<ClaudeControlException>()));
      await disposal.timeout(const Duration(seconds: 1));
      gate.complete();
      expect(repository.isResident(sessionId: testSessionId), isFalse);
      expect(harness.processes.single.killed, isTrue);
    });
  });
}

Future<void> _ensure(ClaudeSessionProcessRepository repository, {required bool createNew}) => repository.ensureResident(
  sessionId: testSessionId,
  directory: "/tmp/project",
  createNew: createNew,
  purpose: ClaudeProcessPurpose.session,
  model: null,
  effort: null,
  permissionMode: null,
  fastMode: false,
  allowedTools: const [],
);

Map<String, Object?> _result() => {
  "type": "result",
  "subtype": "success",
  "session_id": testSessionId,
  "is_error": false,
};

Map<String, Object?> _internalReplay() => {
  "type": "user",
  "session_id": testSessionId,
  "uuid": "model-switch",
  "isReplay": true,
  "message": {
    "role": "user",
    "content": [
      {"type": "text", "text": "<local-command-stdout>Set model to haiku</local-command-stdout>"},
    ],
  },
};

List<Map<String, Object?>> _userFrames(FakeClaudeProcess process) =>
    process.written.where((frame) => frame["type"] == "user").toList(growable: false);

Future<void> _waitForUserFrames(FakeClaudeProcess process, int count) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (_userFrames(process).length >= count) return;
    await pump();
  }
  throw StateError("expected $count user frames");
}

Map<String, Object?> _replayOf(Map<String, Object?> written, {required String uuid}) => {
  ...written,
  "uuid": uuid,
  "isReplay": true,
};

Map<String, Object?> _reencodedImageEcho({required Map<String, Object?> written, required String uuid}) {
  final message = written.field<Map<String, Object?>>("message");
  final content = message.field<List<Object?>>("content");
  final image = expectType<Map<String, Object?>>(content[1]);
  final source = image.field<Map<String, Object?>>("source");
  return {
    ...written,
    "uuid": uuid,
    "message": {
      ...message,
      "content": [
        content.first,
        {
          ...image,
          "cache_control": {"type": "ephemeral"},
          "source": {
            ...source,
            "media_type": "image/jpeg",
            "data": "/9j/4AAQSkZJRg==",
            "cache_control": {"type": "ephemeral"},
          },
        },
      ],
    },
  };
}

final class _ProcessHarness() {
  final List<ClaudeLaunchSpec> specs = [];
  final List<FakeClaudeProcess> processes = [];

  /// The Sesori MCP config each injecting launch could read when it started.
  final List<String> sesoriMcpConfigs = [];
  Future<void>? beforeInitialize;

  Future<ClaudeProcessHandle> spawn(ClaudeLaunchSpec spec) async {
    final process = FakeClaudeProcess();
    specs.add(spec);
    if (spec.sesoriMcp case final config?) {
      sesoriMcpConfigs.add(File(config.path).readAsStringSync());
    }
    processes.add(process);
    unawaited(() async {
      await beforeInitialize;
      final request = await waitForFrame(process, "control_request");
      process.emitControlResponse(requestId: request.field<String>("request_id"), payload: sampleHandshake);
    }());
    return process;
  }

  Future<void> close() async {
    for (final process in processes) {
      await process.close();
    }
  }
}
