import "dart:async";
import "dart:io";

import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  test("correlates response", () async {
    final fixture = _Fixture();
    final response = fixture.client.request(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1));
    fixture.process.emit('{"id":1,"result":"ok"}');
    expect(await response, {"id": 1, "result": "ok"});
    await fixture.dispose();
  });

  test("timeout removes request and late response becomes notification", () async {
    final fixture = _Fixture();
    final notifications = <JsonObject>[];
    fixture.client.notifications.listen(notifications.add);
    await expectLater(
      fixture.client.request(id: 1, frame: {"id": 1}, timeout: Duration.zero),
      throwsA(isA<TimeoutException>()),
    );
    fixture.process.emit('{"id":1,"result":"late"}');
    await _pump();
    expect(notifications.single["result"], "late");
    await fixture.dispose();
  });

  test("dispatch completes after write acceptance before response", () async {
    final fixture = _Fixture();
    final dispatched = await fixture.client.dispatch(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1));
    await fixture.process.stdin.flush();
    expect(fixture.process.frames, ['{"id":1}']);
    var completed = false;
    unawaited(dispatched.response.then((_) => completed = true));
    await _pump();
    expect(completed, isFalse);
    fixture.process.emit('{"id":1,"result":true}');
    expect((await dispatched.response)["result"], true);
    await fixture.dispose();
  });

  test("real IOSink admits concurrent requests and notifications in FIFO order", () async {
    final writeGate = Completer<void>();
    final fixture = _Fixture(candidate: _FakeProcess(writeGate: writeGate));

    final firstStop = fixture.client.dispatch(
      id: 1,
      frame: {"id": 1, "method": "stop"},
      timeout: const Duration(seconds: 1),
    );
    fixture.client.sendFrame(frame: {"method": "cancel-input"});
    final secondStop = fixture.client.dispatch(
      id: 2,
      frame: {"id": 2, "method": "stop"},
      timeout: const Duration(seconds: 1),
    );
    final prompt = fixture.client.dispatch(
      id: 3,
      frame: {"id": 3, "method": "prompt"},
      timeout: const Duration(seconds: 1),
    );
    final dispatched = await Future.wait([firstStop, secondStop, prompt]);

    writeGate.complete();
    await fixture.process.stdin.flush();
    expect(fixture.process.frames, [
      '{"id":1,"method":"stop"}',
      '{"method":"cancel-input"}',
      '{"id":2,"method":"stop"}',
      '{"id":3,"method":"prompt"}',
    ]);
    for (var id = 1; id <= 3; id++) {
      fixture.process.emit('{"id":$id}');
    }
    await Future.wait(dispatched.map((dispatch) => dispatch.response));
    await fixture.dispose();
  });

  test("asynchronous IOSink failure preserves the error for pending responses", () async {
    final error = StateError("broken pipe");
    final fixture = _Fixture(candidate: _FakeProcess(writeError: error));
    final dispatched = await fixture.client.dispatch(
      id: 1,
      frame: {"id": 1},
      timeout: const Duration(seconds: 1),
    );

    await expectLater(dispatched.response, throwsA(same(error)));
    await fixture.dispose();
  });

  test("synchronous IOSink failure does not leave an unhandled pending error", () async {
    final fixture = _Fixture(candidate: _FakeProcess(autoExitOnClose: false));
    await fixture.process.stdin.close();
    final unhandled = <Object>[]; // ignore: no_slop_linter/prefer_specific_type

    await runZonedGuarded<Future<void>>(
      () async {
        await expectLater(
          fixture.client.dispatch(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1)),
          throwsA(isA<StateError>().having((error) => error.message, "message", "StreamSink is closed")),
        );
        await _pump();
      },
      (error, _) => unhandled.add(error),
    );

    expect(unhandled, isEmpty);
    await fixture.dispose();
  });

  test("malformed discard keeps pending and failPending fails all", () async {
    final discard = _Fixture(malformedPolicy: MalformedFramePolicy.discard);
    final waiting = discard.client.request(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1));
    discard.process.emit("bad");
    discard.process.emit('{"id":1,"result":true}');
    expect((await waiting)["result"], true);
    await discard.dispose();

    final fail = _Fixture(malformedPolicy: MalformedFramePolicy.failPending);
    final failed = fail.client.request(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1));
    fail.process.emit("bad");
    await expectLater(failed, throwsStateError);
    await fail.dispose();
  });

  test("non-object policy discards or fails pending", () async {
    final discard = _Fixture(nonObjectPolicy: NonObjectFramePolicy.discard);
    final waiting = discard.client.request(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1));
    discard.process.emit("[]");
    discard.process.emit('{"id":1}');
    await waiting;
    await discard.dispose();

    final fail = _Fixture(nonObjectPolicy: NonObjectFramePolicy.failPending);
    final failed = fail.client.request(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1));
    fail.process.emit("[]");
    await expectLater(failed, throwsStateError);
    await fail.dispose();
  });

  test("stdout error and process exit fail all pending", () async {
    final stdout = _Fixture();
    final first = stdout.client.request(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1));
    await _pump();
    final second = stdout.client.request(id: 2, frame: {"id": 2}, timeout: const Duration(seconds: 1));
    stdout.process.failStdout(StateError("stdout"));
    await expectLater(first, throwsStateError);
    await expectLater(second, throwsStateError);
    await stdout.dispose();

    final exited = _Fixture();
    final order = <String>[];
    final pending = exited.client.request(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1));
    final pendingChecked = pending.then<void>(
      (_) => fail("exit must fail pending response"),
      onError: (Object error) {
        expect("$error", "Bad state: exited 7");
        order.add("pending");
      },
    );
    final exitChecked = exited.client.exit.then((_) => order.add("exit"));
    exited.process.completeExit(7);
    await Future.wait([pendingChecked, exitChecked]);
    expect(order, ["pending", "exit"]);
    await exited.dispose();
  });

  test("exceptional process exit fails pending response before public exit with original error", () async {
    final fixture = _Fixture();
    final error = StateError("exceptional exit");
    final stackTrace = StackTrace.fromString("synthetic exceptional exit");
    final order = <String>[];
    final dispatched = await fixture.client.dispatch(
      id: 1,
      frame: {"id": 1},
      timeout: const Duration(seconds: 1),
    );
    final pendingChecked = dispatched.response.then<void>(
      (_) => fail("exceptional exit must fail pending response"),
      onError: (Object actualError, StackTrace actualStackTrace) {
        expect(actualError, same(error));
        expect(actualStackTrace.toString(), stackTrace.toString());
        order.add("pending");
      },
    );
    final exitChecked = fixture.client.exit.then<void>(
      (_) => fail("exceptional exit must fail public exit"),
      onError: (Object actualError, StackTrace actualStackTrace) {
        expect(actualError, same(error));
        expect(actualStackTrace.toString(), stackTrace.toString());
        order.add("exit");
      },
    );

    fixture.process.failExit(error: error, stackTrace: stackTrace);

    await Future.wait([pendingChecked, exitChecked]);
    expect(order, ["pending", "exit"]);
    await fixture.dispose();
  });

  test("superseded attach reaps late process", () async {
    final client = _client(reapTimeout: const Duration(seconds: 1));
    final token = client.beginAttach();
    await client.reset(reason: StateError("reset"), stackTrace: null, gracefulTimeout: Duration.zero);
    final late = _FakeProcess(autoExitOnForce: false);
    final attach = client.attach(token: token, process: late);
    var completed = false;
    attach.whenComplete(() => completed = true).ignore();
    await _pump();
    expect(late.actions, ["force"]);
    expect(completed, isFalse);
    late.completeExit(0);
    await expectLater(attach, throwsStateError);
    await client.dispose(reason: StateError("done"), gracefulTimeout: Duration.zero);
  });

  test("old generation stdout and exit cannot affect replacement", () async {
    final first = _FakeProcess(autoExitOnClose: false);
    final fixture = _Fixture(candidate: first);
    await fixture.client.reset(reason: StateError("reset"), stackTrace: null, gracefulTimeout: Duration.zero);
    final second = _FakeProcess();
    await fixture.client.attach(token: fixture.client.beginAttach(), process: second);
    final pending = fixture.client.request(id: 2, frame: {"id": 2}, timeout: const Duration(seconds: 1));
    first.emit('{"id":2,"result":"stale"}');
    first.completeExit(9);
    second.emit('{"id":2,"result":"current"}');
    expect((await pending)["result"], "current");
    await fixture.dispose();
  });

  test("old generation exceptional exit cannot affect replacement", () async {
    final first = _FakeProcess(autoExitOnClose: false, autoExitOnForce: false);
    final fixture = _Fixture(candidate: first);
    final staleError = StateError("stale exceptional exit");
    final staleStackTrace = StackTrace.fromString("synthetic stale exceptional exit");
    final staleExitChecked = fixture.client.exit.then<void>(
      (_) => fail("old process exit must preserve its exceptional result"),
      onError: (Object actualError, StackTrace actualStackTrace) {
        expect(actualError, same(staleError));
        expect(actualStackTrace.toString(), staleStackTrace.toString());
      },
    );
    await fixture.client.reset(reason: StateError("reset"), stackTrace: null, gracefulTimeout: Duration.zero);

    final second = _FakeProcess();
    await fixture.client.attach(token: fixture.client.beginAttach(), process: second);
    final pending = fixture.client.request(id: 2, frame: {"id": 2}, timeout: const Duration(seconds: 1));
    first.failExit(error: staleError, stackTrace: staleStackTrace);
    await staleExitChecked;
    second.emit('{"id":2,"result":"current"}');

    expect((await pending)["result"], "current");
    await fixture.dispose();
  });

  test("old generation stdin failure cannot affect replacement", () async {
    final writeGate = Completer<void>();
    final first = _FakeProcess(writeError: StateError("stale stdin"), writeGate: writeGate);
    final fixture = _Fixture(candidate: first);
    final old = await fixture.client.dispatch(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1));
    old.response.ignore();
    await fixture.client.reset(reason: StateError("reset"), stackTrace: null, gracefulTimeout: Duration.zero);

    final second = _FakeProcess();
    await fixture.client.attach(token: fixture.client.beginAttach(), process: second);
    final pending = fixture.client.request(id: 2, frame: {"id": 2}, timeout: const Duration(seconds: 1));
    writeGate.complete();
    await _pump();
    second.emit('{"id":2,"result":"current"}');

    expect((await pending)["result"], "current");
    await fixture.dispose();
  });

  test("reset preserves a caught stack or captures the explicit-reset stack", () async {
    for (final original in [null, StackTrace.fromString("synthetic original source")]) {
      final fixture = _Fixture();
      final reason = StateError("reset reason");
      final request = fixture.client.request(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1));
      final checked = request.then<void>(
        (_) => fail("reset must fail pending"),
        onError: (Object error, StackTrace stack) {
          expect(error, same(reason));
          expect(stack.toString(), original == null ? contains("NdjsonProcessClient._teardown") : original.toString());
        },
      );
      await _pump();
      await fixture.client.reset(reason: reason, stackTrace: original, gracefulTimeout: Duration.zero);
      await checked;
      await fixture.dispose();
    }
  });

  test("reset keeps notifications open and dispose closes them", () async {
    final fixture = _Fixture();
    var done = false;
    fixture.client.notifications.listen((_) {}, onDone: () => done = true);
    await fixture.client.reset(reason: StateError("reset"), stackTrace: null, gracefulTimeout: Duration.zero);
    expect(done, isFalse);
    await fixture.client.dispose(reason: StateError("done"), gracefulTimeout: Duration.zero);
    expect(done, isTrue);
  });

  test("reset completes the detached process exit future", () async {
    final fixture = _Fixture();
    final exit = fixture.client.exit;

    await fixture.client.reset(reason: StateError("reset"), stackTrace: null, gracefulTimeout: Duration.zero);

    expect(await exit.timeout(const Duration(seconds: 1)), 0);
    await fixture.dispose();
  });

  test("concurrent dispose shares teardown and exact order is close graceful force", () async {
    final fixture = _Fixture(candidate: _FakeProcess(autoExitOnClose: false));
    await Future.wait([
      fixture.client.dispose(reason: StateError("done"), gracefulTimeout: Duration.zero),
      fixture.client.dispose(reason: StateError("done"), gracefulTimeout: Duration.zero),
    ]);
    expect(fixture.process.actions, ["stdin-close", "graceful", "force"]);
  });

  test("cleanup failures continue through subscriptions and force kill", () async {
    final process = _FakeProcess(closeError: StateError("close"), gracefulKillError: StateError("graceful"));
    final fixture = _Fixture(candidate: process);
    await fixture.dispose();
    expect(process.actions, ["stdin-close", "graceful", "force"]);
    expect(process.stdoutCancelled, isTrue);
    expect(process.stderrCancelled, isTrue);
  });
}

NdjsonProcessClient _client({
  MalformedFramePolicy malformedFramePolicy = MalformedFramePolicy.discard,
  NonObjectFramePolicy nonObjectFramePolicy = NonObjectFramePolicy.discard,
  Duration reapTimeout = Duration.zero,
}) => NdjsonProcessClient(
  responseCorrelationId: (frame) => frame["id"],
  exitError: (code) => StateError("exited $code"),
  malformedFramePolicy: malformedFramePolicy,
  nonObjectFramePolicy: nonObjectFramePolicy,
  malformedFrameLogPolicy: MalformedFrameLogPolicy.metadataOnly,
  stderrPolicy: StderrPolicy.discard,
  sanitizeForLog: (_) => "<redacted>",
  logTag: "test",
  reapTimeout: reapTimeout,
);

final class _Fixture({
  final _FakeProcess? candidate,
  final MalformedFramePolicy malformedPolicy = MalformedFramePolicy.discard,
  final NonObjectFramePolicy nonObjectPolicy = NonObjectFramePolicy.discard,
}) {
  late final _FakeProcess process = candidate ?? _FakeProcess();
  late final NdjsonProcessClient _transport = _client(
    malformedFramePolicy: malformedPolicy,
    nonObjectFramePolicy: nonObjectPolicy,
  );
  late final Future<void> attached = _transport.attach(token: _transport.beginAttach(), process: process);
  NdjsonProcessClient get client {
    unawaited(attached);
    return _transport;
  }

  Future<void> dispose() async {
    await attached;
    await _transport.dispose(reason: StateError("done"), gracefulTimeout: Duration.zero);
  }
}

final class _FakeProcess({
  final Object? writeError, // ignore: no_slop_linter/prefer_specific_type
  final Completer<void>? writeGate,
  final Object? closeError, // ignore: no_slop_linter/prefer_specific_type
  final Object? gracefulKillError, // ignore: no_slop_linter/prefer_specific_type
  final bool autoExitOnClose = true,
  final bool autoExitOnForce = true,
}) implements NdjsonProcessHandle {
  final StreamController<String> _stdout = StreamController.broadcast(onCancel: () {});
  final StreamController<String> _stderr = StreamController.broadcast(onCancel: () {});
  final Completer<int> _exited = Completer<int>();
  final List<String> actions = [];
  final List<String> frames = [];
  late final IOSink _stdin = IOSink(_RecordingConsumer(process: this));
  bool stdoutCancelled = false;
  bool stderrCancelled = false;

  void emit(String line) => _stdout.add(line);
  void failStdout(Object error) => _stdout.addError(error); // ignore: no_slop_linter/prefer_specific_type
  void completeExit(int code) {
    if (!_exited.isCompleted) _exited.complete(code);
  }

  void failExit({required Object error, required StackTrace stackTrace}) {
    if (!_exited.isCompleted) _exited.completeError(error, stackTrace);
  }

  @override
  IOSink get stdin => _stdin;
  @override
  Stream<String> get stdoutLines => _stdout.stream.transform(_CancelTracker(onCancel: () => stdoutCancelled = true));
  @override
  Stream<String> get stderrLines => _stderr.stream.transform(_CancelTracker(onCancel: () => stderrCancelled = true));
  @override
  Future<int> get done => _exited.future;
  @override
  Future<void> kill({required bool force}) async {
    actions.add(force ? "force" : "graceful");
    if (!force && gracefulKillError != null) throw gracefulKillError!;
    if (force && autoExitOnForce) completeExit(0);
  }
}

final class _RecordingConsumer({required final _FakeProcess process}) implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await process.writeGate?.future;
    if (process.writeError != null) throw process.writeError!;
    await for (final bytes in stream) {
      process.frames.add(String.fromCharCodes(bytes).trim());
    }
  }

  @override
  Future<void> close() async {
    process.actions.add("stdin-close");
    if (process.closeError != null) throw process.closeError!;
    if (process.autoExitOnClose) process.completeExit(0);
  }
}

final class _CancelTracker({required final void Function() onCancel}) extends StreamTransformerBase<String, String> {
  @override
  Stream<String> bind(Stream<String> stream) {
    late StreamSubscription<String> subscription;
    final controller = StreamController<String>();
    controller.onListen = () {
      subscription = stream.listen(controller.add, onError: controller.addError, onDone: controller.close);
    };
    controller.onCancel = () async {
      onCancel();
      await subscription.cancel();
    };
    return controller.stream;
  }
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);
