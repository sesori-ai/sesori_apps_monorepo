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

    test("creates first process and resumes after an accepted turn", () async {
      await _ensure(repository, createNew: true);
      expect(harness.specs.single.launch, isA<ClaudeNewSession>());

      final turn = repository.sendTurn(
        sessionId: testSessionId,
        parts: const [PluginPromptPart.text(text: "hello")],
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

    test("retries a new launch when no first turn was accepted", () async {
      await _ensure(repository, createNew: true);
      await repository.teardown(sessionId: testSessionId);

      await _ensure(repository, createNew: true);

      expect(harness.specs, hasLength(2));
      expect(harness.specs.last.launch, isA<ClaudeNewSession>());
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

Future<void> _ensure(ClaudeSessionProcessRepository repository, {required bool createNew}) => repository.ensureResident(
  sessionId: testSessionId,
  directory: "/tmp/project",
  createNew: createNew,
  model: null,
  effort: null,
  permissionMode: null,
  allowedTools: const [],
);

Map<String, Object?> _result() => {
  "type": "result",
  "subtype": "success",
  "session_id": testSessionId,
  "is_error": false,
};

final class _ProcessHarness {
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
