import "dart:async";
import "dart:convert";

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

    test("preserves launch arguments when optional host services are absent", () async {
      await _ensure(repository, createNew: true);

      expect(harness.specs.single.arguments, isNot(contains("--mcp-config")));
      expect(harness.specs.single.arguments, isNot(contains("--strict-mcp-config")));
    });

    test("writes a bound session MCP config without exposing tokens in argv", () async {
      final services = await _replaceWithAgentToolRepository(repository: repository, harness: harness);
      repository = services.repository;

      await Future.wait([
        _ensure(repository, sessionId: testSessionId, createNew: true),
        _ensure(repository, sessionId: otherTestSessionId, createNew: true),
      ]);

      expect(services.tools.backendSessionIds, unorderedEquals([testSessionId, otherTestSessionId]));
      expect(services.tools.provisioned.map((capability) => capability.id).toSet(), hasLength(2));
      expect(services.files.writes, hasLength(2));
      for (var index = 0; index < harness.specs.length; index++) {
        final capability = services.tools.provisioned[index];
        final spec = harness.specs[index];
        final path = spec.arguments[spec.arguments.indexOf("--mcp-config") + 1];
        final name = path.split("/").last;
        expect(
          jsonDecode(services.files.writes[name]!) as Map<String, Object?>,
          {
            "mcpServers": {
              "sesori-device-canvas": {
                "type": "http",
                "url": capability.url,
                "headers": {"Authorization": "Bearer ${capability.bearerToken}"},
              },
            },
          },
        );
        expect(spec.arguments.join(" "), isNot(contains(capability.bearerToken)));
        expect(spec.arguments, isNot(contains("--strict-mcp-config")));
      }
    });

    test("does not provision MCP for catalog probe children", () async {
      final services = await _replaceWithAgentToolRepository(repository: repository, harness: harness);
      repository = services.repository;
      final catalog = ClaudeCatalogService(
        catalog: const ClaudeBackendCatalogRepository(),
        processes: repository,
        probeSessionId: otherTestSessionId,
        discoveryDirectory: "/tmp/claude-state",
      );

      await catalog.getCatalog(refresh: false);

      expect(services.tools.provisioned, isEmpty);
      expect(services.files.writes, isEmpty);
      expect(harness.specs.single.arguments, isNot(contains("--mcp-config")));
    });

    test("deletes and revokes MCP after a failed connection", () async {
      final services = await _replaceWithAgentToolRepository(repository: repository, harness: harness);
      repository = services.repository;
      harness.spawnError = StateError("spawn failed");

      await expectLater(_ensure(repository, createNew: true), throwsStateError);

      expect(services.files.deletedNames, services.files.writes.keys);
      expect(services.tools.revoked, services.tools.provisioned);
    });

    test("retains failed MCP cleanup for a later repository retry", () async {
      final services = await _replaceWithAgentToolRepository(repository: repository, harness: harness);
      repository = services.repository;
      await _ensure(repository, createNew: true);
      services.tools.revokeFailures = 1;
      services.files.deleteFailures = 1;

      await expectLater(repository.teardown(sessionId: testSessionId), throwsStateError);
      expect(services.tools.revoked, isEmpty);
      expect(services.files.deletedNames, isEmpty);

      await repository.dispose();
      expect(services.tools.revoked, services.tools.provisioned);
      expect(services.files.deletedNames, services.files.writes.keys);
      expect(services.tools.revokeAttempts, 2);
      expect(services.files.deleteAttempts, 2);
    });

    test("retains failed attachment-creation rollback for disposal retry", () async {
      final services = await _replaceWithAgentToolRepository(repository: repository, harness: harness);
      repository = services.repository;
      services.files.writeFailures = 1;
      services.tools.revokeFailures = 1;

      await expectLater(_ensure(repository, createNew: true), throwsStateError);
      expect(services.tools.revoked, isEmpty);

      await repository.dispose();
      expect(services.tools.revoked, services.tools.provisioned);
      expect(services.tools.revokeAttempts, 2);
    });

    test("deletes and revokes MCP on teardown and replacement", () async {
      final services = await _replaceWithAgentToolRepository(repository: repository, harness: harness);
      repository = services.repository;
      await _ensure(repository, createNew: true, effort: ClaudeEffortLevel.low);
      final firstCapability = services.tools.provisioned.single;
      final firstFile = services.files.writes.keys.single;

      await _ensure(repository, createNew: true, effort: ClaudeEffortLevel.high);

      expect(services.tools.revoked, [firstCapability]);
      expect(services.files.deletedNames, [firstFile]);
      expect(services.tools.provisioned, hasLength(2));

      await repository.teardown(sessionId: testSessionId);
      expect(services.tools.revoked, services.tools.provisioned);
      expect(services.files.deletedNames, unorderedEquals(services.files.writes.keys));
    });

    test("deletes and revokes MCP when the child exits", () async {
      final services = await _replaceWithAgentToolRepository(repository: repository, harness: harness);
      repository = services.repository;
      await _ensure(repository, createNew: true);

      harness.processes.single.exit(1);
      await _waitForMcpCleanup(services);

      expect(services.tools.revoked, services.tools.provisioned);
      expect(services.files.deletedNames, services.files.writes.keys);
    });

    test("deletes and revokes MCP when the repository is disposed", () async {
      final services = await _replaceWithAgentToolRepository(repository: repository, harness: harness);
      repository = services.repository;
      await _ensure(repository, createNew: true);

      await repository.dispose();

      expect(services.tools.revoked, services.tools.provisioned);
      expect(services.files.deletedNames, services.files.writes.keys);
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

    test("correlates an unmarked decorated image echo with its prompt", () async {
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
          PluginPromptPart.fileData(mime: "image/JPEG", base64: "aA==", filename: "image.jpg"),
        ],
        promptId: "prompt-image",
      );
      final written = await waitForFrame(process, "user");

      process.emit(_decoratedImageEcho(written: written, uuid: "echo-image"));
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

      await expectLater(residency, throwsStateError);
      await disposal.timeout(const Duration(seconds: 1));
      gate.complete();
      expect(repository.isResident(sessionId: testSessionId), isFalse);
      expect(harness.processes.single.killed, isTrue);
    });
  });
}

Future<void> _ensure(
  ClaudeSessionProcessRepository repository, {
  String sessionId = testSessionId,
  required bool createNew,
  ClaudeEffortLevel? effort,
}) => repository.ensureResident(
  sessionId: sessionId,
  directory: "/tmp/project",
  createNew: createNew,
  model: null,
  effort: effort,
  permissionMode: null,
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

Map<String, Object?> _decoratedImageEcho({required Map<String, Object?> written, required String uuid}) {
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
            "data": "aA",
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
  Object? spawnError;

  Future<ClaudeProcessHandle> spawn(ClaudeLaunchSpec spec) async {
    specs.add(spec);
    if (spawnError case final error?) throw error;
    final process = FakeClaudeProcess();
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

Future<_AgentToolRepository> _replaceWithAgentToolRepository({
  required ClaudeSessionProcessRepository repository,
  required _ProcessHarness harness,
}) async {
  await repository.dispose();
  final services = _AgentToolServices();
  return (
    repository: ClaudeSessionProcessRepository(
      processFactory: harness.spawn,
      binaryPath: "claude",
      environment: const {},
      agentToolServices: services,
    ),
    tools: services.tools,
    files: services.files,
  );
}

Future<void> _waitForMcpCleanup(_AgentToolRepository services) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (services.tools.revoked.isNotEmpty && services.files.deletedNames.isNotEmpty) return;
    await pump();
  }
  throw StateError("MCP attachment was not cleaned up");
}

typedef _AgentToolRepository = ({
  ClaudeSessionProcessRepository repository,
  _AgentToolHost tools,
  _PrivateFiles files,
});

final class _AgentToolServices() implements PluginAgentToolServices {
  @override
  final _AgentToolHost tools = _AgentToolHost();
  final _PrivateFiles files = _PrivateFiles();

  @override
  PluginPrivateFileService get privateFiles => files;
}

final class _AgentToolHost() implements PluginAgentToolHost {
  final List<String?> backendSessionIds = [];
  final List<PluginAgentToolMcpCapability> provisioned = [];
  final List<PluginAgentToolMcpCapability> revoked = [];
  int revokeFailures = 0;
  int revokeAttempts = 0;

  @override
  Future<PluginAgentToolMcpCapability> provisionMcp({required String? backendSessionId}) async {
    backendSessionIds.add(backendSessionId);
    final id = provisioned.length + 1;
    final capability = PluginAgentToolMcpCapability(
      id: "capability-$id",
      url: "http://127.0.0.1:4242/mcp/$id",
      bearerToken: "private-token-$id",
    );
    provisioned.add(capability);
    return capability;
  }

  @override
  Future<void> revokeMcp({required PluginAgentToolMcpCapability capability}) async {
    revokeAttempts++;
    if (revokeFailures > 0) {
      revokeFailures--;
      throw StateError("revoke failed");
    }
    revoked.add(capability);
  }

  @override
  Future<void> bindMcp({
    required PluginAgentToolMcpCapability capability,
    required String backendSessionId,
  }) async {}

  @override
  Future<Map<String, dynamic>> invoke({
    required String backendSessionId,
    required PluginAgentTool tool,
    required Map<String, dynamic> arguments,
  }) async => const {};

  @override
  Future<void> dispose() async {}
}

final class _PrivateFiles() implements PluginPrivateFileService {
  final Map<String, String> writes = {};
  final List<String> deletedNames = [];
  int writeFailures = 0;
  int deleteFailures = 0;
  int deleteAttempts = 0;

  @override
  Future<String> write({required String name, required String contents}) async {
    if (writeFailures > 0) {
      writeFailures--;
      throw StateError("write failed");
    }
    writes[name] = contents;
    return "/bridge-state/$name";
  }

  @override
  Future<void> delete({required String name}) async {
    deleteAttempts++;
    if (deleteFailures > 0) {
      deleteFailures--;
      throw StateError("delete failed");
    }
    deletedNames.add(name);
  }
}
