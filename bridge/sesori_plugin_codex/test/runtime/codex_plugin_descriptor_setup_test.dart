import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CodexPluginDescriptor.inspectSetup", () {
    const stateDirectory = "/state";
    const config = PluginConfig(values: {"port": null, "bin": "codex"});
    // Probes must stay deterministic regardless of what the host machine has
    // installed, so the desktop-app candidate list is injected everywhere.
    const descriptor = CodexPluginDescriptor(desktopAppCliCandidates: []);

    test("declares project-scoped session options", () {
      expect(const CodexPluginDescriptor().sessionOptionsScope, PluginSessionOptionsScope.project);
      expect(const CodexPluginDescriptor().supportsPromptAttachments, isTrue);
    });

    test("advertises install without an explicit binary override", () {
      // Every CI/dev platform this test runs on has a published codex release
      // asset, so the managed install capability is advertised.
      expect(
        descriptor.managementCapabilities(config: config),
        const {
          PluginControlCapability.lifecycle,
          PluginControlCapability.setupRefresh,
          PluginControlCapability.idleTimeout,
          PluginControlCapability.install,
        },
      );
    });

    test("does not advertise install with an explicit binary override", () {
      expect(
        descriptor.managementCapabilities(
          config: const PluginConfig(values: {"port": null, "bin": "/opt/codex/bin/codex"}),
        ),
        const {
          PluginControlCapability.lifecycle,
          PluginControlCapability.setupRefresh,
          PluginControlCapability.idleTimeout,
        },
      );
    });

    test("reports ready after version and read-only authentication probes", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("codex 0.146.0\n"),
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 2,
            stdoutBytes: utf8.encode("Logged in using ChatGPT\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await descriptor.inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady());
      expect(processes.spawnedExecutables, ["codex", "codex"]);
      expect(processes.spawnedArguments, [
        const ["--version"],
        const ["login", "status"],
      ]);
    });

    test("reports a missing default runtime without installing", () async {
      final processes = _ProbeProcessService(
        spawnError: const ProcessException("codex", ["--version"], "missing", 2),
      );

      final result = await descriptor.inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupRuntimeMissing>());
    });

    test("recognizes and authenticates a previously installed managed runtime", () async {
      const manifest = CodexRuntimeManifest();
      final managedBinaryPath = manifest.managedBinaryPath(stateDirectory: stateDirectory);
      final processes = _ProbeProcessService(
        spawnOutcomes: [
          const ProcessException("codex", ["--version"], "missing", 2),
          _ProbeProcess(
            pid: 3,
            stdoutBytes: utf8.encode("codex ${manifest.bundledVersion}\n"),
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 4,
            stdoutBytes: utf8.encode("Logged in using ChatGPT\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await descriptor.inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady());
      expect(processes.spawnedExecutables, ["codex", managedBinaryPath, managedBinaryPath]);
    });

    test("falls back to a desktop-app-bundled CLI when PATH is missing", () async {
      const appCli = "/Applications/ChatGPT.app/Contents/Resources/codex";
      final processes = _ProbeProcessService(
        spawnOutcomes: [
          const ProcessException("codex", ["--version"], "missing", 2),
          _ProbeProcess(
            pid: 3,
            stdoutBytes: utf8.encode("codex-cli 0.146.0\n"),
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 4,
            stdoutBytes: utf8.encode("Logged in using ChatGPT\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await const CodexPluginDescriptor(
        desktopAppCliCandidates: [appCli],
      ).inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady());
      expect(processes.spawnedExecutables, ["codex", appCli, appCli]);
    });

    test("skips an outdated desktop-app CLI in favor of the managed runtime", () async {
      const manifest = CodexRuntimeManifest();
      final managedBinaryPath = manifest.managedBinaryPath(stateDirectory: stateDirectory);
      const appCli = "/Applications/ChatGPT.app/Contents/Resources/codex";
      final processes = _ProbeProcessService(
        spawnOutcomes: [
          const ProcessException("codex", ["--version"], "missing", 2),
          _ProbeProcess(
            pid: 3,
            stdoutBytes: utf8.encode("codex-cli 0.100.0\n"),
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 4,
            stdoutBytes: utf8.encode("codex ${manifest.bundledVersion}\n"),
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 5,
            stdoutBytes: utf8.encode("Logged in using ChatGPT\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await const CodexPluginDescriptor(
        desktopAppCliCandidates: [appCli],
      ).inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady());
      expect(processes.spawnedExecutables, ["codex", appCli, managedBinaryPath, managedBinaryPath]);
    });

    test("reports a missing explicitly configured runtime", () async {
      final processes = _ProbeProcessService(
        spawnError: const ProcessException("/custom/codex", ["--version"], "missing", 2),
      );

      final result = await descriptor.inspectSetup(
        config: const PluginConfig(values: {"port": null, "bin": "/custom/codex"}),
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupRuntimeMissing>());
    });

    test("reports an outdated explicitly configured runtime as unavailable", () async {
      const explicitConfig = PluginConfig(
        values: {"port": null, "bin": "/custom/codex"},
      );
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(
            pid: 9,
            stdoutBytes: utf8.encode("codex 0.100.0\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await descriptor.inspectSetup(
        config: explicitConfig,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnavailable>());
      expect(
        descriptor.managementCapabilities(config: explicitConfig),
        isNot(contains(PluginControlCapability.install)),
      );
      expect(processes.spawnedExecutables, ["/custom/codex"]);
    });

    test("reports authentication required without starting a login flow", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(
            pid: 3,
            stdoutBytes: utf8.encode("codex 0.146.0\n"),
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 4,
            stdoutBytes: utf8.encode("Not logged in\n"),
            exitCode: Future<int>.value(1),
          ),
        ],
      );

      final result = await descriptor.inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupAuthenticationRequired>());
      expect(processes.spawnedArguments, [
        const ["--version"],
        const ["login", "status"],
      ]);
      expect(processes.spawnedArguments, isNot(contains(const ["login"])));
    });

    test("reports unknown without exposing ambiguous authentication output", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(
            pid: 5,
            stdoutBytes: utf8.encode("codex 0.146.0\n"),
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 6,
            stdoutBytes: utf8.encode("account-secret-output\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await descriptor.inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnknown>());
      expect(result.actionHint, isNot(contains("account-secret-output")));
    });

    test("caps authentication output while continuing to classify safely", () async {
      final oversizedOutput = "${List<String>.filled(70 * 1024, "x").join()}logged in";
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(
            pid: 7,
            stdoutBytes: utf8.encode("codex 0.146.0\n"),
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 8,
            stdoutBytes: utf8.encode(oversizedOutput),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await descriptor.inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnknown>());
    });
  });
}

class _ProbeProcessService implements HostProcessService {
  _ProbeProcessService({this.spawnError, List<_ProbeProcess>? processSequence, List<Object>? spawnOutcomes})
    : _processSequence = processSequence ?? const <_ProbeProcess>[],
      _spawnOutcomes = spawnOutcomes;

  final Object? spawnError;
  final List<_ProbeProcess> _processSequence;
  final List<Object>? _spawnOutcomes;
  final List<String> spawnedExecutables = <String>[];
  final List<List<String>> spawnedArguments = <List<String>>[];
  int _nextProcess = 0;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    spawnedExecutables.add(executable);
    spawnedArguments.add(List<String>.from(arguments));
    final outcomes = _spawnOutcomes;
    if (outcomes != null) {
      final outcome = outcomes[_nextProcess++];
      if (outcome is SpawnedProcess) return outcome;
      throw outcome;
    }
    final error = spawnError;
    if (error != null) throw error;
    return _processSequence[_nextProcess++];
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalGraceful({required int pid}) async => _signal(pid);

  @override
  Future<SignalResult> signalForce({required int pid}) async => _signal(pid);

  SignalResult _signal(int pid) => SignalResult(
    pid: pid,
    requestedSignal: ShutdownSignal.force,
    deliveredSignal: ProcessSignal.sigkill,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 7, 18),
  );
}

class _ProbeProcess implements SpawnedProcess {
  _ProbeProcess({required this.pid, required List<int> stdoutBytes, required Future<int> exitCode})
    : _stdoutBytes = stdoutBytes,
      _exitCode = exitCode;

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
