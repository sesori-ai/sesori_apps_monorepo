import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("caps captured output while continuing to drain both process streams", () async {
    final process = _FakeSpawnedProcess(
      stdoutChunks: [utf8.encode("12345"), utf8.encode("67890")],
      stderrChunks: [utf8.encode("abcde"), utf8.encode("fghij")],
    );
    final executor = HostProcessCommandExecutor(
      includeParentEnvironment: true,
      processes: _FakeHostProcessService(process: process),
      runInShell: false,
      maxCapturedOutputCharactersPerStream: 6,
    );

    final result = await executor.run("probe", const []);

    expect(result.stdout, "123456");
    expect(result.stderr, "abcdef");
    expect(process.stdoutChunksDelivered, 2);
    expect(process.stderrChunksDelivered, 2);
  });

  test("timeout force-stops a running command before settling", () async {
    final processes = _FakeHostProcessService(process: _HangingSpawnedProcess());
    final executor = HostProcessCommandExecutor(
      includeParentEnvironment: true,
      processes: processes,
      runInShell: false,
      maxCapturedOutputCharactersPerStream: 6,
    );

    await expectLater(
      executor.runAbortable(
        executable: "updater",
        arguments: const ["update"],
        workingDirectory: null,
        environment: const {},
        timeout: const Duration(milliseconds: 10),
        abortSignal: StartAbortSignal.never,
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(processes.forceSignals, [42]);
  });

  test("abort force-stops a running command before settling", () async {
    final processes = _FakeHostProcessService(process: _HangingSpawnedProcess());
    final executor = HostProcessCommandExecutor(
      includeParentEnvironment: true,
      processes: processes,
      runInShell: false,
      maxCapturedOutputCharactersPerStream: 6,
    );
    final aborted = StartAbortController();

    final run = executor.runAbortable(
      executable: "updater",
      arguments: const ["update"],
      workingDirectory: null,
      environment: const {},
      timeout: const Duration(minutes: 1),
      abortSignal: aborted.signal,
    );
    await Future<void>.delayed(Duration.zero);
    aborted.abort();

    await expectLater(run, throwsA(isA<PluginStartAbortedException>()));
    expect(processes.forceSignals, [42]);
  });

  test("an unsuccessful force signal does not settle before the process exits", () async {
    final process = _HangingSpawnedProcess();
    final processes = _FakeHostProcessService(
      process: process,
      forceSignalWasRequested: false,
      completeExitOnForceSignal: false,
    );
    final executor = HostProcessCommandExecutor(
      includeParentEnvironment: true,
      processes: processes,
      runInShell: false,
      maxCapturedOutputCharactersPerStream: 6,
    );
    final aborted = StartAbortController();
    var settled = false;

    final run = executor.runAbortable(
      executable: "updater",
      arguments: const ["update"],
      workingDirectory: null,
      environment: const {},
      timeout: const Duration(minutes: 1),
      abortSignal: aborted.signal,
    );
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
  final bool forceSignalWasRequested = true,
  final bool completeExitOnForceSignal = true,
}) implements HostProcessService {
  final forceSignals = <int>[];
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
    return process;
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    forceSignals.add(pid);
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
