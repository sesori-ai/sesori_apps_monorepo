import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/src/runtime/codex_runtime_manifest.dart";
import "package:codex_plugin/src/runtime/codex_runtime_selection_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const stateDirectory = "/state";
  const defaultConfig = PluginConfig(values: {"bin": "codex"});
  const environment = <String, String>{"PATH": "/custom/bin", "CODEX_HOME": "/codex-home"};

  CodexRuntimeSelectionService service(
    _FakeHostProcessService processes, {
    List<String> desktopCandidates = const <String>[],
    Duration timeout = const Duration(seconds: 1),
  }) {
    return CodexRuntimeSelectionService(
      processes: processes,
      versionProbeTimeout: timeout,
      maxCapturedOutputCharactersPerStream: 64 * 1024,
      desktopAppCliCandidates: desktopCandidates,
    );
  }

  Future<CodexRuntimeSelection> select(
    CodexRuntimeSelectionService selectionService, {
    PluginConfig config = defaultConfig,
    StartAbortSignal? aborted,
  }) {
    return selectionService.select(
      config: config,
      environment: environment,
      stateDirectory: stateDirectory,
      aborted: aborted ?? StartAbortSignal.never,
    );
  }

  group("CodexRuntimeSelectionService", () {
    test("treats an explicit binary as authoritative without fallback", () async {
      final processes = _FakeHostProcessService([
        _ProbeProcess(stdoutText: "codex 0.100.0\n", exitCode: 0),
      ]);

      final result = await select(
        service(processes, desktopCandidates: const ["/desktop/codex"]),
        config: const PluginConfig(values: {"bin": "/explicit/codex"}),
      );

      expect(
        result,
        isA<CodexRuntimeNotSelected>()
            .having((value) => value.failure, "failure", CodexRuntimeSelectionFailure.unsupportedVersion)
            .having((value) => value.hasExplicitBinary, "hasExplicitBinary", isTrue),
      );
      expect(processes.executables, ["/explicit/codex"]);
    });

    test("prefers a supported PATH runtime before desktop and managed", () async {
      final processes = _FakeHostProcessService([
        _ProbeProcess(stdoutText: "codex 0.140.0\n", exitCode: 0),
      ]);

      final result = await select(service(processes, desktopCandidates: const ["/desktop/codex"]));

      expect(
        result,
        isA<CodexRuntimeSelected>()
            .having((value) => value.binaryPath, "binaryPath", "codex")
            .having((value) => value.source, "source", CodexRuntimeSource.path),
      );
      expect(processes.executables, ["codex"]);
    });

    test("prefers a supported desktop runtime after PATH", () async {
      final processes = _FakeHostProcessService([
        const ProcessException("codex", ["--version"], "missing", 2),
        _ProbeProcess(stdoutText: "codex-cli 0.141.0\n", exitCode: 0),
      ]);

      final result = await select(service(processes, desktopCandidates: const ["/desktop/codex"]));

      expect(
        result,
        isA<CodexRuntimeSelected>()
            .having((value) => value.binaryPath, "binaryPath", "/desktop/codex")
            .having((value) => value.source, "source", CodexRuntimeSource.desktopApp),
      );
      expect(processes.executables, ["codex", "/desktop/codex"]);
    });

    test("uses managed only after PATH and desktop and forwards the environment", () async {
      const manifest = CodexRuntimeManifest();
      final managedPath = manifest.managedBinaryPath(stateDirectory: stateDirectory);
      final processes = _FakeHostProcessService([
        _ProbeProcess(stdoutText: "codex 0.100.0\n", exitCode: 0),
        const ProcessException("/desktop/codex", ["--version"], "missing", 2),
        _ProbeProcess(stdoutText: "codex ${manifest.bundledVersion}\n", exitCode: 0),
      ]);

      final result = await select(service(processes, desktopCandidates: const ["/desktop/codex"]));

      expect(
        result,
        isA<CodexRuntimeSelected>()
            .having((value) => value.binaryPath, "binaryPath", managedPath)
            .having((value) => value.source, "source", CodexRuntimeSource.managed)
            .having((value) => value.rejectedPathVersion.toString(), "rejectedPathVersion", "0.100.0"),
      );
      expect(processes.executables, ["codex", "/desktop/codex", managedPath]);
      expect(processes.environments, everyElement(environment));
      expect(processes.arguments, everyElement(const ["--version"]));
    });

    test("requires the exact bundled managed version", () async {
      const manifest = CodexRuntimeManifest();
      final processes = _FakeHostProcessService([
        const ProcessException("codex", ["--version"], "missing", 2),
        _ProbeProcess(stdoutText: "codex 999.0.0\n", exitCode: 0),
      ]);

      final result = await select(service(processes));

      expect(
        result,
        isA<CodexRuntimeNotSelected>()
            .having((value) => value.failure, "failure", CodexRuntimeSelectionFailure.executableMissing)
            .having((value) => value.hasExplicitBinary, "hasExplicitBinary", isFalse),
      );
      expect(processes.executables.last, manifest.managedBinaryPath(stateDirectory: stateDirectory));
    });

    test("classifies explicit probe failures", () async {
      final cases = <(Object, CodexRuntimeSelectionFailure)>[
        (
          const ProcessException("/explicit/codex", ["--version"], "missing", 2),
          CodexRuntimeSelectionFailure.executableMissing,
        ),
        (StateError("spawn failed"), CodexRuntimeSelectionFailure.probeFailed),
        (_ProbeProcess(stdoutText: "codex 0.146.0\n", exitCode: 1), CodexRuntimeSelectionFailure.nonZeroExit),
        (_ProbeProcess(stdoutText: "not a version\n", exitCode: 0), CodexRuntimeSelectionFailure.unrecognizedVersion),
        (_ProbeProcess(stdoutText: "codex 0.100.0\n", exitCode: 0), CodexRuntimeSelectionFailure.unsupportedVersion),
      ];

      for (final (outcome, failure) in cases) {
        final result = await select(
          service(_FakeHostProcessService([outcome])),
          config: const PluginConfig(values: {"bin": "/explicit/codex"}),
        );
        expect(
          result,
          isA<CodexRuntimeNotSelected>().having((value) => value.failure, "failure", failure),
          reason: "$failure",
        );
      }
    });

    test("classifies a timed out probe", () async {
      final processes = _FakeHostProcessService([
        _ProbeProcess(stdoutText: "", exitCodeFuture: Completer<int>().future),
      ]);

      final result = await select(
        service(processes, timeout: const Duration(milliseconds: 10)),
        config: const PluginConfig(values: {"bin": "/explicit/codex"}),
      );

      expect(
        result,
        isA<CodexRuntimeNotSelected>().having(
          (value) => value.failure,
          "failure",
          CodexRuntimeSelectionFailure.probeTimedOut,
        ),
      );
      expect(processes.forceSignaledPids, hasLength(1));
    });

    test("aborts before spawning the first probe", () async {
      final processes = _FakeHostProcessService(const <Object>[]);
      final abort = StartAbortController()..abort();

      await expectLater(
        select(service(processes), aborted: abort.signal),
        throwsA(isA<PluginStartAbortedException>()),
      );
      expect(processes.executables, isEmpty);
    });

    test("aborts at the boundary after a completed probe", () async {
      final processes = _FakeHostProcessService([
        _ProbeProcess(stdoutText: "codex 0.146.0\n", exitCode: 0),
      ]);

      await expectLater(
        select(service(processes), aborted: _AbortOnSecondCheck()),
        throwsA(isA<PluginStartAbortedException>()),
      );
      expect(processes.executables, ["codex"]);
    });
  });
}

class _FakeHostProcessService implements HostProcessService {
  _FakeHostProcessService(this._outcomes);

  final List<Object> _outcomes;
  final List<String> executables = <String>[];
  final List<List<String>> arguments = <List<String>>[];
  final List<Map<String, String>?> environments = <Map<String, String>?>[];
  final List<int> forceSignaledPids = <int>[];
  int _nextOutcome = 0;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    executables.add(executable);
    this.arguments.add(List<String>.unmodifiable(arguments));
    environments.add(environment == null ? null : Map<String, String>.unmodifiable(environment));
    final outcome = _outcomes[_nextOutcome++];
    if (outcome is SpawnedProcess) return outcome;
    throw outcome;
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    forceSignaledPids.add(pid);
    return _signal(pid);
  }

  @override
  Future<SignalResult> signalGraceful({required int pid}) async => _signal(pid);

  SignalResult _signal(int pid) => SignalResult(
    pid: pid,
    requestedSignal: ShutdownSignal.force,
    deliveredSignal: ProcessSignal.sigkill,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 8, 11),
  );
}

class _ProbeProcess implements SpawnedProcess {
  _ProbeProcess({required String stdoutText, int? exitCode, Future<int>? exitCodeFuture})
    : pid = _nextPid++,
      _stdoutBytes = utf8.encode(stdoutText),
      _exitCode = exitCodeFuture ?? Future<int>.value(exitCode!);

  static int _nextPid = 1;

  @override
  final int pid;

  final List<int> _stdoutBytes;
  final Future<int> _exitCode;

  @override
  Future<int> get exitCode => _exitCode;

  @override
  Stream<List<int>> get stdout => Stream<List<int>>.value(_stdoutBytes);

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  ProcessIdentity get identity => throw UnimplementedError();
}

class _AbortOnSecondCheck implements StartAbortSignal {
  int _checks = 0;

  @override
  bool get isAborted => ++_checks >= 2;

  @override
  Future<void> get whenAborted => Completer<void>().future;
}
