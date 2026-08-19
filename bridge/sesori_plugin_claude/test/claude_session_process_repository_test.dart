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
