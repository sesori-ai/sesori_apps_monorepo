import "dart:async";

import "package:claude_plugin/claude_plugin.dart";
import "package:claude_plugin/claude_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/claude_stream_client_test_factory.dart";

void main() {
  group("ClaudeSessionService", () {
    late _ServiceHarness harness;

    setUp(() {
      harness = _ServiceHarness();
    });

    tearDown(() async {
      await harness.dispose();
    });

    test("serializes queued turns for one session", () async {
      harness.enqueue("first", model: "haiku");
      harness.enqueue("second", model: "haiku");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");

      expect(_userFrames(process), hasLength(1));
      process.emit(_result());
      await _waitForUserFrames(process, 2);
      process.emit(_result());
      await harness.waitForIdle();

      expect(_userText(process, 0), "first");
      expect(_userText(process, 1), "second");
    });

    test("abort fences a queued turn and cancels the running turn", () async {
      harness.enqueue("first", model: "haiku");
      harness.enqueue("second", model: "haiku");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");

      final abort = harness.service.abort(sessionId: testSessionId);
      final interrupt = await _waitForControlSubtype(process, "interrupt");
      process.emitControlResponse(requestId: interrupt["request_id"]! as String, payload: const {});
      await abort;
      process.emit(_result());
      await harness.waitForIdle();

      expect(_userFrames(process), hasLength(1));
      expect(harness.repository.isResident(sessionId: testSessionId), isFalse);
    });

    test("next turn resumes in a fresh process after abort", () async {
      harness.enqueue("first", model: "haiku");
      final first = await harness.firstProcess;
      await waitForFrame(first, "user");

      final abort = harness.service.abort(sessionId: testSessionId);
      final interrupt = await _waitForControlSubtype(first, "interrupt");
      first.emitControlResponse(requestId: interrupt["request_id"]! as String, payload: const {});
      await abort;
      await harness.waitForIdle();

      harness.enqueue("second", model: "haiku");
      final second = await harness.processAt(1);
      await waitForFrame(second, "user");

      expect(harness.specs.last.launch, isA<ClaudeResumedSession>());
      expect(_userText(second, 0), "second");
    });

    test("abort tears down the process when interrupt fails", () async {
      await harness.dispose();
      harness = _ServiceHarness(failInterrupt: true);
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");

      await harness.service.abort(sessionId: testSessionId);
      await harness.waitForIdle();

      expect(harness.repository.isResident(sessionId: testSessionId), isFalse);
    });

    test("interruptActiveWork aborts and waits for active sessions within its budget", () async {
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");

      final interruption = harness.service.interruptActiveWork(
        budget: const Duration(seconds: 1),
      );
      final interrupt = await _waitForControlSubtype(process, "interrupt");
      process.emitControlResponse(requestId: interrupt["request_id"]! as String, payload: const {});
      process.emit(_result());

      expect(await interruption, {testSessionId});
      expect(harness.service.currentWorkState, PluginWorkState.idle);
    });

    test("routes control asks and clears them when the process exits", () async {
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");
      process.emit({
        "type": "control_request",
        "request_id": "permission-1",
        "request": {
          "subtype": "can_use_tool",
          "tool_name": "Write",
          "input": {"file_path": "a.dart"},
        },
      });
      await pump();
      expect(harness.approvals.pendingPermissionsForSession(sessionId: testSessionId), hasLength(1));

      process.exit(1);
      await harness.waitForIdle();

      expect(harness.approvals.pendingPermissionsForSession(sessionId: testSessionId), isEmpty);
      expect(harness.events.whereType<BridgeSseSessionError>(), hasLength(1));
    });

    test("reaps an idle process and transparently resumes the next turn", () async {
      harness.enqueue("first", model: "haiku");
      final first = await harness.firstProcess;
      await waitForFrame(first, "user");
      first.emit({
        "type": "control_request",
        "request_id": "permission-1",
        "session_id": testSessionId,
        "request": {
          "subtype": "can_use_tool",
          "tool_name": "Write",
          "input": {"file_path": "a.dart"},
          "permission_suggestions": [
            {
              "type": "addRules",
              "destination": "session",
              "behavior": "allow",
              "rules": [
                {"toolName": "Write"},
              ],
            },
          ],
        },
      });
      await pump();
      expect(harness.approvals.replyPermission(id: "br-1", reply: PluginPermissionReply.always), isTrue);
      first.emit(_result());
      await harness.waitForIdle();

      harness.clock.elapse();
      await pump();
      expect(harness.repository.isResident(sessionId: testSessionId), isFalse);

      harness.enqueue("second", model: "haiku");
      final second = await harness.processAt(1);
      await waitForFrame(second, "user");

      expect(harness.specs.last.launch, isA<ClaudeResumedSession>());
      expect(harness.specs.last.model, "haiku");
      expect(harness.specs.last.allowedTools, ["Write"]);
    });

    test("aborting an idle session preserves its scheduled reap", () async {
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");
      process.emit(_result());
      await harness.waitForIdle();

      await harness.service.abort(sessionId: testSessionId);
      harness.clock.elapse();
      await pump();

      expect(harness.repository.isResident(sessionId: testSessionId), isFalse);
    });

    test("concurrent disposal waits for an in-flight idle teardown", () async {
      await harness.dispose();
      harness = _ServiceHarness(stdinCloseCompletes: false);
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");
      process.emit(_result());
      await harness.waitForIdle();
      harness.clock.elapse();
      await _waitForStdinClose(process);

      final first = harness.service.dispose();
      final second = harness.service.dispose();
      var completed = false;
      unawaited(first.then((_) => completed = true));
      await pump();

      expect(identical(first, second), isTrue);
      expect(completed, isFalse);
      process.completeStdinClose();
      await first;
      expect(completed, isTrue);
    });

    test("defers the idle reap while a ScheduleWakeup is pending", () async {
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");
      process.emit(_scheduleWakeupFrame(delaySeconds: 600));
      process.emit(_result());
      await harness.waitForIdle();

      harness.clock.elapse();
      await pump();

      expect(harness.repository.isResident(sessionId: testSessionId), isTrue);
    });

    test("reaps a process whose wakeup is one idle timeout stale", () async {
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");
      process.emit(_scheduleWakeupFrame(delaySeconds: -100000));
      process.emit(_result());
      await harness.waitForIdle();

      harness.clock.elapse();
      await pump();

      expect(harness.repository.isResident(sessionId: testSessionId), isFalse);
    });

    test("surfaces a CLI self-started wakeup turn as busy and idle again on its result", () async {
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");
      process.emit(_scheduleWakeupFrame(delaySeconds: 600));
      process.emit(_result());
      await harness.waitForIdle();
      harness.events.clear();

      // The wakeup fires: the CLI streams a turn the bridge never enqueued.
      process.emit(_assistantTextFrame(text: "waking up"));
      await harness.waitForBusy();

      expect(harness.service.currentWorkState, PluginWorkState.busy);
      expect(await _status(harness), isA<PluginSessionStatusBusy>());
      expect(harness.events.whereType<BridgeSseSessionStatus>(), isNotEmpty);

      process.emit(_result());
      await harness.waitForIdle();

      expect(await _status(harness), isA<PluginSessionStatusIdle>());
      expect(harness.events.whereType<BridgeSseSessionIdle>(), hasLength(1));

      // The finished self-started turn cleared the wakeup and rearmed the reap.
      harness.clock.elapse();
      await pump();
      expect(harness.repository.isResident(sessionId: testSessionId), isFalse);
    });

    test("abort interrupts a self-started wakeup turn", () async {
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");
      process.emit(_scheduleWakeupFrame(delaySeconds: 600));
      process.emit(_result());
      await harness.waitForIdle();

      process.emit(_assistantTextFrame(text: "waking up"));
      await harness.waitForBusy();

      final abort = harness.service.abort(sessionId: testSessionId);
      final interrupt = await _waitForControlSubtype(process, "interrupt");
      process.emitControlResponse(requestId: interrupt["request_id"]! as String, payload: const {});
      await abort;
      await harness.waitForIdle();

      expect(harness.repository.isResident(sessionId: testSessionId), isFalse);
      expect(harness.service.currentWorkState, PluginWorkState.idle);
    });

    test("a ScheduleWakeup stop call clears the pending wakeup", () async {
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");
      process.emit(_scheduleWakeupFrame(delaySeconds: 600));
      process.emit(_result());
      await harness.waitForIdle();

      // The fired turn ends the loop: ScheduleWakeup({stop: true}) then result.
      process.emit(_scheduleWakeupStopFrame());
      await harness.waitForBusy();
      process.emit(_result());
      await harness.waitForIdle();

      harness.clock.elapse();
      await pump();
      expect(harness.repository.isResident(sessionId: testSessionId), isFalse);
    });

    test("reads the idle timeout live at each reap arm", () async {
      harness.idleTimeout = null;
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");
      process.emit(_result());
      await harness.waitForIdle();

      // Reaping disabled: no delay armed, process stays resident.
      harness.clock.elapse();
      await pump();
      expect(harness.repository.isResident(sessionId: testSessionId), isTrue);

      // Settings change takes effect at the next idle transition.
      harness.idleTimeout = const Duration(minutes: 1);
      harness.enqueue("second");
      await _waitForUserFrames(process, 2);
      process.emit(_result());
      await harness.waitForIdle();
      harness.clock.elapse();
      await pump();
      expect(harness.repository.isResident(sessionId: testSessionId), isFalse);
    });

    test("a process exit clears the pending wakeup", () async {
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");
      process.emit(_scheduleWakeupFrame(delaySeconds: 600));
      process.emit(_result());
      await harness.waitForIdle();

      process.exit(0);
      await pump();

      harness.clock.elapse();
      await pump();
      expect(harness.repository.isResident(sessionId: testSessionId), isFalse);
    });

    test("delete waits for an in-flight idle teardown", () async {
      await harness.dispose();
      harness = _ServiceHarness(stdinCloseCompletes: false);
      harness.enqueue("first");
      final process = await harness.firstProcess;
      await waitForFrame(process, "user");
      process.emit(_result());
      await harness.waitForIdle();
      harness.clock.elapse();
      await _waitForStdinClose(process);

      final deletion = harness.service.deleteSession(sessionId: testSessionId);
      var completed = false;
      unawaited(deletion.then((_) => completed = true));
      await pump();
      expect(completed, isFalse);

      process.completeStdinClose();
      await deletion;
      expect(completed, isTrue);
    });
  });
}

final class _ServiceHarness({final bool stdinCloseCompletes = true, final bool failInterrupt = false}) {
  /// Mutable so tests can exercise runtime settings changes.
  Duration? idleTimeout = const Duration(minutes: 5);

  this {
    repository = ClaudeSessionProcessRepository(
      processFactory: _spawn,
      binaryPath: "claude",
      environment: const {},
    );
    approvals = ClaudeApprovalRegistry(
      emit: events.add,
      respond: ({required sessionId, required requestId, required payload}) =>
          repository.answerControlRequest(sessionId: sessionId, requestId: requestId, payload: payload),
    );
    service = ClaudeSessionService(
      processes: repository,
      approvals: approvals,
      clock: clock,
      resolveIdleTimeout: () => idleTimeout,
    );
    subscription = service.events.listen(events.add);
  }

  final List<ClaudeLaunchSpec> specs = [];
  final List<FakeClaudeProcess> processes = [];
  final List<BridgeSseEvent> events = [];
  final _ControlledClock clock = _ControlledClock();
  late final ClaudeSessionProcessRepository repository;
  late final ClaudeApprovalRegistry approvals;
  late final ClaudeSessionService service;
  late final StreamSubscription<BridgeSseEvent> subscription;

  Future<FakeClaudeProcess> get firstProcess => processAt(0);

  Future<ClaudeProcessHandle> _spawn(ClaudeLaunchSpec spec) async {
    final process = FakeClaudeProcess(stdinCloseCompletes: stdinCloseCompletes);
    specs.add(spec);
    processes.add(process);
    unawaited(() async {
      final request = await waitForFrame(process, "control_request");
      process.emitControlResponse(requestId: request["request_id"]! as String, payload: sampleHandshake);
      if (failInterrupt) {
        final interrupt = await _waitForControlSubtype(process, "interrupt");
        process.emitControlError(requestId: interrupt["request_id"]! as String, error: "interrupt failed");
      }
    }());
    return process;
  }

  void enqueue(String text, {String? model}) {
    unawaited(
      service
          .enqueueTurn(
            sessionId: testSessionId,
            directory: "/tmp/project",
            createNew: true,
            parts: [PluginPromptPart.text(text: text)],
            model: model,
            effort: null,
            permissionMode: null,
          )
          .catchError((Object _) {}),
    );
  }

  Future<FakeClaudeProcess> processAt(int index) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (processes.length > index) return processes[index];
      await pump();
    }
    throw StateError("process $index was not spawned");
  }

  Future<void> waitForIdle() => service.currentWorkState == PluginWorkState.idle
      ? Future<void>.value()
      : service.workState.firstWhere((state) => state == PluginWorkState.idle);

  Future<void> waitForBusy() => service.currentWorkState == PluginWorkState.busy
      ? Future<void>.value()
      : service.workState.firstWhere((state) => state == PluginWorkState.busy);

  Future<void> dispose() async {
    await service.dispose();
    await subscription.cancel();
    for (final process in processes) {
      await process.close();
    }
  }
}

final class _ControlledClock() extends ServerClock {
  final List<Completer<void>> _delays = [];

  @override
  Future<void> delay({required Duration duration}) {
    final completer = Completer<void>();
    _delays.add(completer);
    return completer.future;
  }

  void elapse() {
    for (final delay in _delays.toList(growable: false)) {
      if (!delay.isCompleted) delay.complete();
    }
    _delays.clear();
  }
}

List<Map<String, Object?>> _userFrames(FakeClaudeProcess process) =>
    process.written.where((frame) => frame["type"] == "user").toList(growable: false);

String? _userText(FakeClaudeProcess process, int index) {
  final message = _userFrames(process)[index]["message"]! as Map<String, Object?>;
  final content = message["content"]! as List<Object?>;
  return (content.single! as Map<String, Object?>)["text"] as String?;
}

Future<void> _waitForUserFrames(FakeClaudeProcess process, int count) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (_userFrames(process).length >= count) return;
    await pump();
  }
  throw StateError("expected $count user frames, saw ${_userFrames(process).length}");
}

Future<void> _waitForStdinClose(FakeClaudeProcess process) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (process.stdinClosed) return;
    await pump();
  }
  throw StateError("process stdin was not closed");
}

Future<Map<String, Object?>> _waitForControlSubtype(FakeClaudeProcess process, String subtype) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    for (final frame in process.written) {
      final request = frame["request"];
      if (frame["type"] == "control_request" && request is Map && request["subtype"] == subtype) return frame;
    }
    await pump();
  }
  throw StateError("control request '$subtype' was not written");
}

Map<String, Object?> _result() => {
  "type": "result",
  "subtype": "success",
  "session_id": testSessionId,
  "is_error": false,
};

Future<PluginSessionStatus> _status(_ServiceHarness harness) async =>
    harness.service.sessionStatuses[testSessionId]!;

Map<String, Object?> _scheduleWakeupFrame({required int delaySeconds}) => _assistantFrame(content: [
  {
    "type": "tool_use",
    "id": "wakeup-1",
    "name": "ScheduleWakeup",
    "input": {"delaySeconds": delaySeconds, "prompt": "continue the loop"},
  },
]);

Map<String, Object?> _scheduleWakeupStopFrame() => _assistantFrame(content: [
  {
    "type": "tool_use",
    "id": "wakeup-2",
    "name": "ScheduleWakeup",
    "input": {"stop": true},
  },
]);

Map<String, Object?> _assistantTextFrame({required String text}) => _assistantFrame(content: [
  {"type": "text", "text": text},
]);

Map<String, Object?> _assistantFrame({required List<Map<String, Object?>> content}) => {
  "type": "assistant",
  "session_id": testSessionId,
  "message": {
    "id": "msg-${_frameSequence++}",
    "model": "claude-sonnet-4-5",
    "content": content,
  },
};

int _frameSequence = 0;
