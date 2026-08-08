import "dart:convert";
import "dart:io";

import "package:opencode_plugin/src/runtime/open_code_plugin_descriptor.dart";
import "package:opencode_plugin/src/runtime/open_code_runtime_manifest.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodePluginDescriptor.inspectSetup", () {
    const stateDirectory = "/state";
    const automaticConfig = PluginConfig(
      values: {
        "no-auto-start": false,
        "port": null,
        "host": "127.0.0.1",
        "password": "",
        "bin": null,
        "no-password": false,
      },
    );

    test("reports ready after only a bounded version probe", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(
          pid: 1,
          stdoutBytes: utf8.encode("opencode 1.18.11\n"),
          exitCode: Future<int>.value(0),
        ),
      );

      final result = await const OpenCodePluginDescriptor().inspectSetup(
        config: automaticConfig,
        processes: processes,
        environment: const <String, String>{"PATH": "/usr/bin"},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady());
      expect(processes.spawnedExecutables, ["opencode"]);
      expect(processes.spawnedArguments, [
        const ["--version"],
      ]);
    });

    test("reports a missing default runtime without installing", () async {
      final processes = _ProbeProcessService(
        spawnError: const ProcessException("opencode", ["--version"], "missing", 2),
      );

      final result = await const OpenCodePluginDescriptor().inspectSetup(
        config: automaticConfig,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupRuntimeMissing>());
    });

    test("reports missing when PATH and the existing managed runtime are unusable", () async {
      final processes = _ProbeProcessService(
        spawnOutcomes: [
          _ProbeProcess(
            pid: 2,
            stdoutBytes: utf8.encode("broken PATH shim output\n"),
            exitCode: Future<int>.value(1),
          ),
          const ProcessException("managed-opencode", ["--version"], "missing", 2),
        ],
      );

      final result = await const OpenCodePluginDescriptor().inspectSetup(
        config: automaticConfig,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupRuntimeMissing>());
      expect(result.actionHint, isNot(contains("broken PATH shim output")));
    });

    test("recognizes a previously installed managed runtime when PATH is missing", () async {
      const manifest = OpenCodeRuntimeManifest();
      final managedBinaryPath = manifest.managedBinaryPath(stateDirectory: stateDirectory);
      final processes = _ProbeProcessService(
        spawnOutcomes: [
          const ProcessException("opencode", ["--version"], "missing", 2),
          _ProbeProcess(
            pid: 2,
            stdoutBytes: utf8.encode("opencode ${manifest.bundledVersion}\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await const OpenCodePluginDescriptor().inspectSetup(
        config: automaticConfig,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady());
      expect(processes.spawnedExecutables, ["opencode", managedBinaryPath]);
    });

    test("reports a missing explicitly configured executable", () async {
      final processes = _ProbeProcessService(
        spawnError: const ProcessException("/custom/opencode", ["--version"], "missing", 2),
      );

      final result = await const OpenCodePluginDescriptor().inspectSetup(
        config: const PluginConfig(
          values: {
            "no-auto-start": false,
            "port": null,
            "host": "127.0.0.1",
            "password": "",
            "bin": "/custom/opencode",
            "no-password": false,
          },
        ),
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupRuntimeMissing>());
    });

    test("a too-old default runtime stays in an installable state with the install capability", () async {
      // Pins the phone gate invariant: while the install capability is
      // advertised (default binary), a too-old runtime maps to runtimeMissing
      // (installable), never to unavailable.
      final processes = _ProbeProcessService(
        spawnOutcomes: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("opencode 0.0.1\n"),
            exitCode: Future<int>.value(0),
          ),
          const ProcessException("managed-opencode", ["--version"], "missing", 2),
        ],
      );

      const descriptor = OpenCodePluginDescriptor();
      final result = await descriptor.inspectSetup(
        config: automaticConfig,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupRuntimeMissing>());
      expect(
        descriptor.managementCapabilities(config: automaticConfig),
        contains(PluginControlCapability.install),
      );
    });

    test("a too-old explicit binary is unavailable and never advertises install", () async {
      const explicitConfig = PluginConfig(
        values: {
          "no-auto-start": false,
          "port": null,
          "host": "127.0.0.1",
          "password": "",
          "bin": "/custom/opencode",
          "no-password": false,
        },
      );
      final processes = _ProbeProcessService(
        process: _ProbeProcess(
          pid: 1,
          stdoutBytes: utf8.encode("opencode 0.0.1\n"),
          exitCode: Future<int>.value(0),
        ),
      );

      const descriptor = OpenCodePluginDescriptor();
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
    });

    test("reports unknown without exposing unrecognized command output", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(
          pid: 2,
          stdoutBytes: utf8.encode("account-secret-output\n"),
          exitCode: Future<int>.value(0),
        ),
      );

      final result = await const OpenCodePluginDescriptor().inspectSetup(
        config: automaticConfig,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnknown>());
      expect(result.actionHint, isNot(contains("account-secret-output")));
    });

    test("attach mode is ready without probing, provisioning, or starting", () async {
      final processes = _ProbeProcessService(spawnError: StateError("must not spawn"));

      final result = await const OpenCodePluginDescriptor().inspectSetup(
        config: const PluginConfig(
          values: {
            "no-auto-start": true,
            "port": "4096",
            "host": "127.0.0.1",
            "password": "",
            "bin": null,
            "no-password": false,
          },
        ),
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady());
      expect(processes.spawnedExecutables, isEmpty);
    });
  });
}

/// A [HostProcessService] that either throws on [spawn] (to simulate ENOENT) or
/// returns a single canned [_ProbeProcess]. Records the spawn arguments and any
/// force-kill it is asked to deliver.
class _ProbeProcessService implements HostProcessService {
  _ProbeProcessService({this.spawnError, this.process, List<Object>? spawnOutcomes}) : _spawnOutcomes = spawnOutcomes;

  final Object? spawnError;
  final _ProbeProcess? process;
  final List<Object>? _spawnOutcomes;
  int _nextOutcome = 0;
  final List<String> spawnedExecutables = <String>[];
  final List<List<String>> spawnedArguments = <List<String>>[];
  final List<int> forceSignals = <int>[];

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
      final outcome = outcomes[_nextOutcome++];
      if (outcome is SpawnedProcess) return outcome;
      throw outcome;
    }
    final error = spawnError;
    if (error != null) {
      throw error;
    }
    return process!;
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalGraceful({required int pid}) async => _signal(pid);

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    forceSignals.add(pid);
    return _signal(pid);
  }

  SignalResult _signal(int pid) => SignalResult(
    pid: pid,
    requestedSignal: ShutdownSignal.force,
    deliveredSignal: ProcessSignal.sigkill,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 6, 1),
  );
}

/// A canned [SpawnedProcess] with a fixed stdout payload and a caller-supplied
/// [exitCode] future (which may never complete, to simulate a hang).
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
