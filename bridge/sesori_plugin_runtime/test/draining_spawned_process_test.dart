import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  test("drains immediately and keeps output available to later listeners", () async {
    final inner = _FakeSpawnedProcess();
    final process = DrainingSpawnedProcess(inner: inner);

    inner.stdoutController.add(<int>[1]);
    inner.stderrController.add(<int>[2]);
    await Future<void>.delayed(Duration.zero);

    final stdout = <List<int>>[];
    final stderr = <List<int>>[];
    process.stdout.listen(stdout.add);
    process.stderr.listen(stderr.add);
    inner.stdoutController.add(<int>[3]);
    inner.stderrController.add(<int>[4]);
    await Future<void>.delayed(Duration.zero);

    expect(
      stdout,
      equals(<List<int>>[
        <int>[3],
      ]),
    );
    expect(
      stderr,
      equals(<List<int>>[
        <int>[4],
      ]),
    );
    inner.completeExit();
  });

  test("delegates process properties", () {
    final inner = _FakeSpawnedProcess();
    final process = DrainingSpawnedProcess(inner: inner);

    expect(process.pid, equals(inner.pid));
    expect(process.identity, same(inner.identity));
    expect(process.stdin, same(inner.stdin));
    expect(process.exitCode, same(inner.exitCode));
    inner.completeExit();
  });

  test("exit failure stays fail-soft", () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final inner = _FakeSpawnedProcess();
      DrainingSpawnedProcess(inner: inner);
      inner.failExit();
      await Future<void>.delayed(Duration.zero);
    }, (error, _) => errors.add(error));

    expect(errors, isEmpty);
  });

  test("keeps draining until both output streams reach EOF", () async {
    final inner = _FakeSpawnedProcess();
    DrainingSpawnedProcess(inner: inner);

    inner.completeExit();
    await Future<void>.delayed(Duration.zero);

    expect(inner.stdoutPaused, isFalse);
    expect(inner.stderrPaused, isFalse);
    inner.stdoutController.add(<int>[1]);
    inner.stderrController.add(<int>[2]);
    await inner.stdoutController.close();
    await inner.stderrController.close();
  });
}

final class _FakeSpawnedProcess() implements SpawnedProcess {
  this {
    stdoutController = StreamController<List<int>>(
      onPause: () => stdoutPaused = true,
      onResume: () => stdoutPaused = false,
    );
    stderrController = StreamController<List<int>>(
      onPause: () => stderrPaused = true,
      onResume: () => stderrPaused = false,
    );
  }

  late final StreamController<List<int>> stdoutController;
  late final StreamController<List<int>> stderrController;
  bool stdoutPaused = false;
  bool stderrPaused = false;
  final Completer<int> _exit = Completer<int>();
  final StreamController<List<int>> _stdinController = StreamController<List<int>>();

  @override
  final int pid = 42;

  @override
  final ProcessIdentity identity = ProcessIdentity(
    pid: 42,
    startMarker: "start",
    executablePath: "/bin/runtime",
    commandLine: "/bin/runtime serve",
    ownerUser: null,
    platform: "macos",
    capturedAt: DateTime.utc(2026),
  );

  @override
  late final IOSink stdin = IOSink(_stdinController.sink);

  @override
  Stream<List<int>> get stdout => stdoutController.stream;

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  @override
  Future<int> get exitCode => _exit.future;

  void completeExit() => _exit.complete(0);

  void failExit() => _exit.completeError(StateError("exit failed"));
}
