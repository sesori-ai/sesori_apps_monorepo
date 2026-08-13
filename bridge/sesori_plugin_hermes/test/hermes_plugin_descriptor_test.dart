import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:hermes_plugin/hermes_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("HermesRuntimeManifest", () {
    test("pins the minimum ACP adapter version the bridge supports", () {
      expect(HermesRuntimeManifest.minAcpVersion.toString(), "0.20.0");
    });

    test("parses the bare adapter version `hermes acp --version` prints", () {
      expect(HermesRuntimeManifest.tryParseVersion(value: "0.20.0\n")?.toString(), "0.20.0");
      expect(HermesRuntimeManifest.tryParseVersion(value: "v0.20.0")?.toString(), "0.20.0");
    });

    test("rejects unparseable output", () {
      expect(HermesRuntimeManifest.tryParseVersion(value: "hermes-acp 0.20"), isNull);
      expect(HermesRuntimeManifest.tryParseVersion(value: ""), isNull);
    });
  });

  group("HermesPluginDescriptor", () {
    const stateDirectory = "/state";
    const config = PluginConfig(
      values: {
        HermesPluginDescriptor.binOption: HermesBinary.defaultBinary,
      },
    );

    test("pins the identity and harness facts", () {
      expect(const HermesPluginDescriptor().id, "hermes");
      expect(const HermesPluginDescriptor().displayName, "Hermes Agent");
      expect(const HermesPluginDescriptor().projectOwnership, PluginProjectOwnership.bridgeDerived);
      expect(const HermesPluginDescriptor().sessionOptionsScope, PluginSessionOptionsScope.plugin);
      expect(const HermesPluginDescriptor().supportsPromptAttachments, isTrue,
          reason: "Hermes advertises prompt image support");
    });

    test("declares only the binary option and no install capability", () {
      const descriptor = HermesPluginDescriptor();
      expect(descriptor.options, hasLength(1));
      expect(descriptor.options.single.name, HermesPluginDescriptor.binOption);
      expect(
        descriptor.managementCapabilities(config: config),
        isNot(contains(PluginControlCapability.install)),
        reason: "Hermes installs itself; the bridge never manages its runtime",
      );
    });

    test("reports ready after version and status probes", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(pid: 1, stdoutBytes: utf8.encode("0.20.0\n"), exitCode: Future<int>.value(0)),
          _ProbeProcess(
            pid: 2,
            stdoutBytes: utf8.encode("Model: deepseek-v4-flash\nProvider: OpenCode Go\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady());
      expect(processes.spawnedExecutables, ["hermes", "hermes"]);
      expect(processes.spawnedArguments, [
        const ["acp", "--version"],
        const ["status"],
      ]);
    });

    test("reports runtime missing when the CLI cannot spawn", () async {
      final processes = _ProbeProcessService(
        spawnError: const ProcessException("hermes", []),
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupRuntimeMissing>());
      expect(
        (result as PluginSetupRuntimeMissing).actionHint,
        contains("Install Hermes Agent"),
      );
    });

    test("reports unknown when the host process seam fails for a non-spawn reason", () async {
      final processes = _ProbeProcessService(
        spawnError: StateError("host process seam unavailable"),
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(
        result,
        isA<PluginSetupUnknown>(),
        reason: "a non-ENOENT spawn failure is not proof of a missing runtime",
      );
    });

    test("reports runtime missing with an update hint for a pre-ACP install", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode(""),
            stderrBytes: utf8.encode("Usage: hermes ...\ninvalid choice: 'acp'\n"),
            exitCode: Future<int>.value(2),
          ),
        ],
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupRuntimeMissing>());
      expect(
        (result as PluginSetupRuntimeMissing).actionHint,
        contains("Update Hermes"),
        reason: "the binary exists but predates the acp subcommand",
      );
    });

    test("reports unavailable when the ACP adapter is below the floor", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(pid: 1, stdoutBytes: utf8.encode("0.19.0\n"), exitCode: Future<int>.value(0)),
        ],
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnavailable>());
    });

    test("reports unknown when the version output is unrecognized", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(pid: 1, stdoutBytes: utf8.encode("not-a-version\n"), exitCode: Future<int>.value(0)),
        ],
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnknown>());
    });

    test("reports authentication required when no model is configured", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(pid: 1, stdoutBytes: utf8.encode("0.20.0\n"), exitCode: Future<int>.value(0)),
          _ProbeProcess(
            pid: 2,
            stdoutBytes: utf8.encode("Model: (not set)\nProvider: none\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupAuthenticationRequired>());
    });

    test("uses an explicit --hermes-bin override for every probe", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(pid: 1, stdoutBytes: utf8.encode("0.20.0\n"), exitCode: Future<int>.value(0)),
          _ProbeProcess(
            pid: 2,
            stdoutBytes: utf8.encode("Model: gpt-5.4\nProvider: openai\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: const PluginConfig(values: {HermesPluginDescriptor.binOption: "/custom/hermes"}),
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady());
      expect(processes.spawnedExecutables, ["/custom/hermes", "/custom/hermes"]);
    });

    test("start spawns exactly one `hermes acp` process and connects", () async {
      const descriptor = HermesPluginDescriptor(
        buildPlugin: _buildTestPlugin,
      );
      spawnedAcpProcesses.clear();
      final handledFrameIds = <Object?>{};
      var responding = true;

      final responsePump = () async {
        while (responding) {
          for (final process in spawnedAcpProcesses) {
            for (final frame in process.written) {
              final id = frame["id"];
              if (id == null || !handledFrameIds.add(id)) continue;
              if (frame["method"] == "initialize") {
                process.emit({
                  "jsonrpc": "2.0",
                  "id": id,
                  "result": const {
                    "protocolVersion": 1,
                    "agentCapabilities": <String, dynamic>{},
                    "authMethods": <Object?>[],
                  },
                });
              }
            }
          }
          await Future<void>.delayed(Duration.zero);
        }
      }();

      final plugin = await descriptor.start(
        _StartPluginHost(
          processes: _ProbeProcessService(
            spawnError: StateError("injected plugin must own the test process"),
          ),
        ),
      );
      responding = false;
      await responsePump;

      expect(
        spawnedAcpProcesses,
        hasLength(1),
        reason: "descriptor startup must only initialize the live ACP process",
      );

      await plugin.shutdown(budget: null);
      for (final process in spawnedAcpProcesses) {
        await process.close();
      }
    });
  });
}

/// Injected test seam: builds a [HermesPlugin] backed by a fake process and
/// records every spawned fake for the response pump.
HermesPlugin _buildTestPlugin({
  required String binaryPath,
  required String launchDirectory,
  required AcpProcessFactory processFactory,
}) {
  return HermesPlugin(
    binaryPath: binaryPath,
    launchDirectory: launchDirectory,
    processFactory: (_) async {
      final process = FakeAcpProcess();
      spawnedAcpProcesses.add(process);
      return process;
    },
  );
}

// Keep the injected factory's captured processes reachable without plumbing
// through the typedef (the test seam closure above shares this list).
final List<FakeAcpProcess> spawnedAcpProcesses = <FakeAcpProcess>[];

class _StartPluginHost({@override required final HostProcessService processes}) implements PluginHost {
  @override
  PluginConfig get config => const PluginConfig(
    values: {
      HermesPluginDescriptor.binOption: HermesBinary.defaultBinary,
    },
  );

  @override
  Map<String, String> get environment => const {"HOME": "/tmp"};

  @override
  String? get provisionedRuntimePath => null;

  @override
  ServerClock get clock => const ServerClock();

  @override
  StartAbortSignal get startAborted => StartAbortSignal.never;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A [HostProcessService] that either throws on [spawn] (to simulate ENOENT)
/// or returns canned [_ProbeProcess]es in order. Records the spawn arguments.
class _ProbeProcessService({
  final Object? spawnError,
  final List<_ProbeProcess>? processSequence,
}) implements HostProcessService {
  int _nextProcess = 0;
  final List<String> spawnedExecutables = <String>[];
  final List<List<String>> spawnedArguments = <List<String>>[];

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
    final error = spawnError;
    if (error != null) {
      throw error;
    }
    return processSequence![_nextProcess++];
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
    attemptedAt: DateTime.utc(2026, 6, 1),
  );
}

/// A canned [SpawnedProcess] with fixed stdout/stderr payloads and a
/// caller-supplied [exitCode] future.
class _ProbeProcess({
  @override required final int pid,
  required final List<int> _stdoutBytes,
  final List<int> _stderrBytes = const <int>[],
  required final Future<int> _exitCode,
}) implements SpawnedProcess {
  @override
  Future<int> get exitCode => _exitCode;

  @override
  Stream<List<int>> get stdout => Stream<List<int>>.value(_stdoutBytes);

  @override
  Stream<List<int>> get stderr => Stream<List<int>>.value(_stderrBytes);

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  ProcessIdentity get identity => throw UnimplementedError();
}
