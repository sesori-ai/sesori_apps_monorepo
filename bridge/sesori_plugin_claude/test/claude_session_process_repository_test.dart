import "dart:async";

import "package:claude_plugin/claude_plugin.dart";
import "package:claude_plugin/claude_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/claude_stream_client_test_factory.dart";

void main() {
  group("ClaudeSessionProcessRepository", () {
    late _ProcessHarness harness;
    late ClaudeSessionProcessRepository repository;

    setUp(() {
      harness = _ProcessHarness();
      repository = ClaudeSessionProcessRepository(
        processFactory: harness.spawn,
        binaryPath: "claude",
        environment: const {},
      );
    });

    tearDown(() async {
      await repository.dispose();
      await harness.close();
    });

    test("inventory reads do not create or resume a process", () async {
      final result = await repository.getMcpInventory(scope: const PluginMcpSessionScope(sessionId: testSessionId));
      expect(result, isA<PluginMcpInventoryUnavailable>().having(
        (value) => value.reason, "reason", PluginMcpInventoryUnavailableReason.liveSessionRequired,
      ));
      final unsupported = await repository.getMcpInventory(scope: const PluginMcpHarnessScope());
      expect(unsupported, isA<PluginMcpInventoryUnavailable>().having(
        (value) => value.reason, "reason", PluginMcpInventoryUnavailableReason.unsupportedScope,
      ));
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
          requestId: request["request_id"]! as String,
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
        process.emitControlResponse(requestId: request["request_id"]! as String, payload: {});
        expect(await result, isA<PluginMcpActionCompleted>());
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
      process.emitControlResponse(requestId: request["request_id"]! as String, payload: {"mcpServers": []});
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
        process.emitControlResponse(requestId: request["request_id"]! as String, payload: {"renamedServers": []});
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
      process.emitControlResponse(requestId: request["request_id"]! as String, payload: {
        "mcpServers": [{"name": "fixture", "status": "connected", "tools": <Map<String, dynamic>>[]}],
      });
      expect((await result as PluginMcpInventorySnapshot).entries, hasLength(1));
      expect(harness.specs, hasLength(1));
    });

    test("inventory control rejection retains the original diagnostic cause", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final result = repository.getMcpInventory(scope: const PluginMcpSessionScope(sessionId: testSessionId));
      await pump();
      final request = process.written.lastWhere((frame) => frame["type"] == "control_request");
      process.emitControlError(requestId: request["request_id"]! as String, error: "fixture native rejection");
      final failed = await result as PluginMcpInventoryReadFailed;
      expect(failed.cause, isA<ClaudeControlException>().having((error) => error.message, "message", "fixture native rejection"));
      expect(failed.causeStackTrace.toString(), isNotEmpty);
      expect(harness.specs, hasLength(1));
    });

    test("process exit during an inventory read returns a read failure without resuming", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final result = repository.getMcpInventory(scope: const PluginMcpSessionScope(sessionId: testSessionId));
      await pump();
      process.exit(1);
      expect(await result, isA<PluginMcpInventoryReadFailed>().having((value) => value.cause, "cause", isA<ClaudeControlException>()));
      expect(harness.specs, hasLength(1));
    });

    test("teardown during inventory reads returns a typed failure", () async {
      await _ensure(repository, createNew: true);
      final result = repository.getMcpInventory(scope: const PluginMcpSessionScope(sessionId: testSessionId));
      await pump();
      await repository.teardown(sessionId: testSessionId);
      expect(await result, isA<PluginMcpInventoryReadFailed>().having(
        (value) => value.cause, "cause", isA<ClaudeControlException>().having(
          (error) => error.message, "message", "ClaudeStreamClient disposed",
        ),
      ));
      expect(harness.specs, hasLength(1));
    });

    test("creates first process and resumes after an accepted turn", () async {
      await _ensure(repository, createNew: true);
      expect(harness.specs.single.launch, isA<ClaudeNewSession>());

      final turn = repository.sendTurn(
        sessionId: testSessionId,
        parts: const [PluginPromptPart.text(text: "hello")],
        promptId: null,
      );
      expect(turn.accepted, isTrue);
      await waitForFrame(harness.processes.single, "user");
      harness.processes.single.emit(_result());
      expect(await turn.outcome, isA<ClaudeTurnCompleted>());

      await repository.teardown(sessionId: testSessionId);
      await _ensure(repository, createNew: true);

      expect(harness.specs, hasLength(2));
      expect(harness.specs.last.launch, isA<ClaudeResumedSession>());
    });

    test("settles steering input with the result after its replay", () async {
      await _ensure(repository, createNew: true);
      final process = harness.processes.single;
      final first = repository.sendTurn(
        sessionId: testSessionId,
        parts: const [PluginPromptPart.text(text: "first")],
        promptId: "prompt-first",
      );
      final second = repository.sendTurn(
        sessionId: testSessionId,
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
            if (event.message case ClaudeUserMessage(raw: {"isReplay": true})) {
              replayPromptIds.add(event.promptId);
            }
          });
      final first = repository.sendTurn(
        sessionId: testSessionId,
        parts: const [PluginPromptPart.text(text: "first")],
        promptId: "prompt-first",
      );
      final second = repository.sendTurn(
        sessionId: testSessionId,
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
        parts: const [PluginPromptPart.text(text: "first")],
        promptId: "prompt-first",
      );
      final firstFrame = await waitForFrame(process, "user");
      process.emit(_result());
      await first.outcome;

      process.emit(_replayOf(firstFrame, uuid: "late-first"));
      final second = repository.sendTurn(
        sessionId: testSessionId,
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
          parts: const [PluginPromptPart.text(text: "fails")],
          promptId: "prompt-fails",
        ),
        throwsA(isA<ClaudeControlException>()),
      );
      final next = repository.sendTurn(
        sessionId: testSessionId,
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
        parts: const [PluginPromptPart.text(text: "hello")],
        promptId: null,
      );
      expect(turn.accepted, isTrue);
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

      final dispatch = repository.sendTurn(
        sessionId: testSessionId,
        parts: const [PluginPromptPart.fileData(mime: "application/pdf", base64: "secret", filename: "a.pdf")],
        promptId: null,
      );

      expect(dispatch.accepted, isFalse);
      expect(await dispatch.outcome, isA<ClaudeTurnFailed>());
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
  final message = (written["message"]! as Map).cast<String, Object?>();
  final content = (message["content"]! as List).cast<Object?>();
  final image = (content[1]! as Map).cast<String, Object?>();
  final source = (image["source"]! as Map).cast<String, Object?>();
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
  Future<void>? beforeInitialize;

  Future<ClaudeProcessHandle> spawn(ClaudeLaunchSpec spec) async {
    final process = FakeClaudeProcess();
    specs.add(spec);
    processes.add(process);
    unawaited(() async {
      await beforeInitialize;
      final request = await waitForFrame(process, "control_request");
      process.emitControlResponse(requestId: request["request_id"]! as String, payload: sampleHandshake);
    }());
    return process;
  }

  Future<void> close() async {
    for (final process in processes) {
      await process.close();
    }
  }
}
