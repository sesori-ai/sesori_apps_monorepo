import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

HostProcessCommandExecutor _executor({required HostProcessService processes}) => HostProcessCommandExecutor(
  includeParentEnvironment: true,
  processes: processes,
  runInShell: false,
  maxCapturedOutputCharactersPerStream: 6,
);

Future<CommandResult> _runUpdate({
  required HostProcessCommandExecutor executor,
  required Duration timeout,
  required StartAbortSignal abortSignal,
}) => executor.runAbortable(
  executable: "updater",
  arguments: const ["update"],
  workingDirectory: null,
  environment: const {},
  timeout: timeout,
  abortSignal: abortSignal,
);

void main() {
  test("caps captured output while continuing to drain both process streams", () async {
    final process = _FakeSpawnedProcess(
      stdoutChunks: [utf8.encode("12345"), utf8.encode("67890")],
      stderrChunks: [utf8.encode("abcde"), utf8.encode("fghij")],
    );
    final executor = _executor(processes: _FakeHostProcessService(process: process));

    final result = await executor.run("probe", const []);

    expect(result.stdout, "123456");
    expect(result.stderr, "abcdef");
    expect(process.stdoutChunksDelivered, 2);
    expect(process.stderrChunksDelivered, 2);
  });

  test("timeout force-stops a running command before settling", () async {
    final processes = _FakeHostProcessService(process: _HangingSpawnedProcess());
    final executor = _executor(processes: processes);

    await expectLater(
      _runUpdate(executor: executor, timeout: const Duration(milliseconds: 10), abortSignal: StartAbortSignal.never),
      throwsA(isA<TimeoutException>()),
    );
    expect(processes.forceSignals, [42]);
  });

  for (final abortsDuringSpawn in [true, false]) {
    test("${abortsDuringSpawn ? "abort" : "timeout"} during spawn terminates the late child before settling", () async {
      final process = _HangingSpawnedProcess();
      final spawnGate = Completer<void>();
      final processes = _FakeHostProcessService(
        process: process,
        spawnGate: spawnGate.future,
        completeExitOnForceSignal: false,
      );
      final executor = _executor(processes: processes);
      final aborted = StartAbortController();
      var settled = false;

      final run = _runUpdate(
        executor: executor,
        timeout: abortsDuringSpawn ? const Duration(minutes: 1) : const Duration(milliseconds: 100),
        abortSignal: aborted.signal,
      );
      unawaited(run.then<void>((_) => settled = true, onError: (Object _, StackTrace _) => settled = true));
      await Future<void>.delayed(abortsDuringSpawn ? Duration.zero : const Duration(milliseconds: 120));
      if (abortsDuringSpawn) aborted.abort();
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);

      spawnGate.complete();
      await processes.forceSignaled.future;
      expect(settled, isFalse);
      process.completeExit(-9);

      await expectLater(run, throwsA(abortsDuringSpawn ? isA<PluginStartAbortedException>() : isA<TimeoutException>()));
    });
  }

  test("abort preserves its failure when spawn never settles", () async {
    final processes = _FakeHostProcessService(
      process: _HangingSpawnedProcess(),
      spawnGate: Completer<void>().future,
    );
    final executor = _executor(processes: processes);
    final aborted = StartAbortController();
    final run = _runUpdate(executor: executor, timeout: const Duration(milliseconds: 20), abortSignal: aborted.signal);

    await Future<void>.delayed(Duration.zero);
    aborted.abort();

    await expectLater(
      run.timeout(const Duration(milliseconds: 200)),
      throwsA(isA<PluginStartAbortedException>()),
    );
    expect(processes.forceSignals, isEmpty);
  });

  test("abort force-stops a running command before settling", () async {
    final processes = _FakeHostProcessService(process: _HangingSpawnedProcess());
    final executor = _executor(processes: processes);
    final aborted = StartAbortController();

    final run = _runUpdate(executor: executor, timeout: const Duration(minutes: 1), abortSignal: aborted.signal);
    await Future<void>.delayed(Duration.zero);
    aborted.abort();

    await expectLater(run, throwsA(isA<PluginStartAbortedException>()));
    expect(processes.forceSignals, [42]);
  });

  test("abort during output drain reports cancellation after the exited child settles", () async {
    final process = _DrainPendingSpawnedProcess();
    final processes = _FakeHostProcessService(process: process);
    final executor = _executor(processes: processes);
    final aborted = StartAbortController();

    final run = _runUpdate(executor: executor, timeout: const Duration(minutes: 1), abortSignal: aborted.signal);
    await process.drainStarted.future;
    process.completeExit(0);
    await Future<void>.delayed(Duration.zero);
    aborted.abort();
    process.completeDrain();

    await expectLater(run, throwsA(isA<PluginStartAbortedException>()));
    expect(processes.forceSignals, isEmpty);
  });

  test("an unsuccessful force signal does not settle before the process exits", () async {
    final process = _HangingSpawnedProcess();
    final processes = _FakeHostProcessService(
      process: process,
      forceSignalWasRequested: false,
      completeExitOnForceSignal: false,
    );
    final executor = _executor(processes: processes);
    final aborted = StartAbortController();
    var settled = false;

    final run = _runUpdate(executor: executor, timeout: const Duration(minutes: 1), abortSignal: aborted.signal);
    unawaited(run.then<void>((_) => settled = true, onError: (Object _, StackTrace _) => settled = true));
    await Future<void>.delayed(Duration.zero);
    aborted.abort();
    await Future<void>.delayed(Duration.zero);

    expect(processes.forceSignals, [42]);
    expect(settled, isFalse);

    process.completeExit(-9);
    await expectLater(run, throwsA(isA<PluginStartAbortedException>()));
  });
}

class _FakeHostProcessService({
  required final SpawnedProcess process,
  final Future<void>? spawnGate,
  final bool forceSignalWasRequested = true,
  final bool completeExitOnForceSignal = true,
}) implements HostProcessService {
  final forceSignals = <int>[];
  final forceSignaled = Completer<void>();
  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) async {
    expect(includeParentEnvironment, isTrue);
    final gate = spawnGate;
    if (gate != null) await gate;
    return process;
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    forceSignals.add(pid);
    if (!forceSignaled.isCompleted) forceSignaled.complete();
    if (completeExitOnForceSignal) {
      final spawnedProcess = process;
      if (spawnedProcess is _HangingSpawnedProcess) spawnedProcess.completeExit(-9);
    }
    return SignalResult(
      pid: pid,
      requestedSignal: ShutdownSignal.force,
      deliveredSignal: ProcessSignal.sigkill,
      wasRequested: forceSignalWasRequested,
      attemptedAt: DateTime.now(),
    );
  }

  @override
  Future<SignalResult> signalGraceful({required int pid}) => throw UnsupportedError("not used");
}

class _HangingSpawnedProcess() implements SpawnedProcess {
  final Completer<int> _exit = Completer<int>();

  void completeExit(int exitCode) {
    if (!_exit.isCompleted) _exit.complete(exitCode);
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  int get pid => 42;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DrainPendingSpawnedProcess() implements SpawnedProcess {
  final drainStarted = Completer<void>();
  final Completer<void> _drain = Completer<void>();
  final Completer<int> _exit = Completer<int>();

  void completeDrain() => _drain.complete();

  void completeExit(int exitCode) => _exit.complete(exitCode);

  @override
  Future<int> get exitCode => _exit.future;

  @override
  int get pid => 42;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  Stream<List<int>> get stdout async* {
    drainStarted.complete();
    await _drain.future;
    yield utf8.encode("done");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSpawnedProcess({required final List<List<int>> stdoutChunks, required final List<List<int>> stderrChunks})
    implements SpawnedProcess {
  int stdoutChunksDelivered = 0;
  int stderrChunksDelivered = 0;

  @override
  Future<int> get exitCode => Future<int>.value(0);

  @override
  ProcessIdentity get identity => throw UnsupportedError("not used");

  @override
  int get pid => 42;

  @override
  Stream<List<int>> get stderr async* {
    for (final chunk in stderrChunks) {
      stderrChunksDelivered++;
      yield chunk;
    }
  }

  @override
  IOSink get stdin => throw UnsupportedError("not used");

  @override
  Stream<List<int>> get stdout async* {
    for (final chunk in stdoutChunks) {
      stdoutChunksDelivered++;
      yield chunk;
    }
  }
}
