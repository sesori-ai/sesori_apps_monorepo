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
    expect(fixture.process.frames, ['{"id":1}']);
    var completed = false;
    unawaited(dispatched.response.then((_) => completed = true));
    await _pump();
    expect(completed, isFalse);
    fixture.process.emit('{"id":1,"result":true}');
    expect((await dispatched.response)["result"], true);
    await fixture.dispose();
  });

  test("dispatch preserves synchronous write error", () async {
    final error = StateError("broken pipe");
    final fixture = _Fixture(candidate: _FakeProcess(writeError: error));
    await expectLater(
      fixture.client.dispatch(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1)),
      throwsA(same(error)),
    );
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
    final pending = exited.client.request(id: 1, frame: {"id": 1}, timeout: const Duration(seconds: 1));
    exited.process.completeExit(7);
    await expectLater(pending, throwsA(predicate((error) => "$error" == "Bad state: exited 7")));
    await exited.dispose();
  });

  test("superseded attach reaps late process", () async {
    final client = _client();
    final token = client.beginAttach();
    await client.reset(reason: StateError("reset"), gracefulTimeout: Duration.zero);
    final late = _FakeProcess();
    await expectLater(client.attach(token: token, process: late), throwsStateError);
    expect(late.actions, ["force"]);
    await client.dispose(reason: StateError("done"), gracefulTimeout: Duration.zero);
  });

  test("old generation stdout and exit cannot affect replacement", () async {
    final first = _FakeProcess(autoExitOnClose: false);
    final fixture = _Fixture(candidate: first);
    await fixture.client.reset(reason: StateError("reset"), gracefulTimeout: Duration.zero);
    final second = _FakeProcess();
    await fixture.client.attach(token: fixture.client.beginAttach(), process: second);
    final pending = fixture.client.request(id: 2, frame: {"id": 2}, timeout: const Duration(seconds: 1));
    first.emit('{"id":2,"result":"stale"}');
    first.completeExit(9);
    second.emit('{"id":2,"result":"current"}');
    expect((await pending)["result"], "current");
    await fixture.dispose();
  });

  test("reset keeps notifications open and dispose closes them", () async {
    final fixture = _Fixture();
    var done = false;
    fixture.client.notifications.listen((_) {}, onDone: () => done = true);
    await fixture.client.reset(reason: StateError("reset"), gracefulTimeout: Duration.zero);
    expect(done, isFalse);
    await fixture.client.dispose(reason: StateError("done"), gracefulTimeout: Duration.zero);
    expect(done, isTrue);
  });

  test("reset completes the detached process exit future", () async {
    final fixture = _Fixture();
    final exit = fixture.client.exit;

    await fixture.client.reset(reason: StateError("reset"), gracefulTimeout: Duration.zero);

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
}) => NdjsonProcessClient(
  responseCorrelationId: (frame) => frame["id"],
  exitError: (code) => StateError("exited $code"),
  malformedFramePolicy: malformedFramePolicy,
  nonObjectFramePolicy: nonObjectFramePolicy,
  malformedFrameLogPolicy: MalformedFrameLogPolicy.metadataOnly,
  stderrPolicy: StderrPolicy.discard,
  sanitizeForLog: (_) => "<redacted>",
  logTag: "test",
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
  final Object? closeError, // ignore: no_slop_linter/prefer_specific_type
  final Object? gracefulKillError, // ignore: no_slop_linter/prefer_specific_type
  final bool autoExitOnClose = true,
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
    if (force) completeExit(0);
  }
}

final class _RecordingConsumer({required final _FakeProcess process}) implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
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
