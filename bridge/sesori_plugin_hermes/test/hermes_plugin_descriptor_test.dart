import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:hermes_plugin/hermes_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
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
      expect(
        const HermesPluginDescriptor().supportsPromptAttachments,
        isTrue,
        reason: "Hermes advertises prompt image support",
      );
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

    test("ensureRuntime resolves a supported PATH adapter", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("hermes-acp v0.20.0\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
        ],
        servesAcp: false,
      );

      final events = await const HermesPluginDescriptor()
          .ensureRuntime(
            host: _StartPluginHost(
              processes: processes,
              config: config,
              provisionedRuntimePath: null,
            ),
          )
          .toList();

      expect(
        events,
        [isA<ProvisionReady>().having((event) => event.binaryPath, "binaryPath", HermesBinary.defaultBinary)],
      );
      expect(processes.spawnedArguments, [
        const ["acp", "--version"],
      ]);
    });

    test("ensureRuntime revalidates an explicit binary override", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("0.20.1\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
        ],
        servesAcp: false,
      );

      final events = await const HermesPluginDescriptor()
          .ensureRuntime(
            host: _StartPluginHost(
              processes: processes,
              config: const PluginConfig(
                values: {HermesPluginDescriptor.binOption: "/custom/hermes"},
              ),
              provisionedRuntimePath: null,
            ),
          )
          .toList();

      expect(
        events,
        [isA<ProvisionReady>().having((event) => event.binaryPath, "binaryPath", "/custom/hermes")],
      );
      expect(processes.spawnedExecutables, ["/custom/hermes"]);
      expect(processes.spawnedArguments, [
        const ["acp", "--version"],
      ]);
    });

    test("reports ready after version and status probes", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("0.20.0\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 2,
            stdoutBytes: utf8.encode("Model: deepseek-v4-flash\nProvider: OpenCode Go\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
        ],
        servesAcp: false,
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady.versioned(runtimeVersion: "0.20.0"));
      expect(processes.spawnedExecutables, ["hermes", "hermes"]);
      expect(processes.spawnedArguments, [
        const ["acp", "--version"],
        const ["status"],
      ]);
    });

    test("reports runtime missing when the CLI cannot spawn", () async {
      final processes = _ProbeProcessService(
        spawnError: const ProcessException("hermes", [], "No such file", 2),
        processSequence: const [],
        servesAcp: false,
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

    test("reports runtime missing for a Windows shell command-not-found result", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: const [],
            stderrBytes: utf8.encode(
              "'hermes' is not recognized as an internal or external command,\r\n"
              "operable program or batch file.\r\n",
            ),
            exitCode: Future<int>.value(1),
          ),
        ],
        servesAcp: false,
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupRuntimeMissing>());
    });

    test("reports unknown when the host process seam fails for a non-spawn reason", () async {
      final processes = _ProbeProcessService(
        spawnError: StateError("host process seam unavailable"),
        processSequence: const [],
        servesAcp: false,
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
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode(""),
            stderrBytes: utf8.encode("Usage: hermes ...\ninvalid choice: 'acp'\n"),
            exitCode: Future<int>.value(2),
          ),
        ],
        servesAcp: false,
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

    test("reports unknown for an unrelated ACP command failure", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: const [],
            stderrBytes: utf8.encode("ACP initialization error: configuration unavailable\n"),
            exitCode: Future<int>.value(1),
          ),
        ],
        servesAcp: false,
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnknown>());
    });

    test("reports unavailable when Hermes Agent is below the supported floor", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("0.19.0\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
        ],
        servesAcp: false,
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnavailable>());
    });

    test("an outdated explicit binary points back to the configured path", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("0.19.0\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
        ],
        servesAcp: false,
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: const PluginConfig(values: {HermesPluginDescriptor.binOption: "/custom/hermes"}),
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnavailable>());
      expect((result as PluginSetupUnavailable).actionHint, contains("configured Hermes CLI path"));
    });

    test("reports unknown when the version output is unrecognized", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("not-a-version\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
        ],
        servesAcp: false,
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
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("0.20.0\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 2,
            stdoutBytes: utf8.encode("Model: (not set)\nProvider: none\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
        ],
        servesAcp: false,
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupAuthenticationRequired>());
      expect(result.runtimeVersion, "0.20.0");
    });

    test("reports authentication required when a model has no provider", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("0.20.0\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 2,
            stdoutBytes: utf8.encode("Model: deepseek-v4-flash\nProvider: none\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
        ],
        servesAcp: false,
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupAuthenticationRequired>());
      expect(result.runtimeVersion, "0.20.0");
    });

    test("reports unknown when the status command exits nonzero", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("0.20.0\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 2,
            stdoutBytes: utf8.encode("Model: deepseek-v4-flash\nProvider: OpenCode Go\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(1),
          ),
        ],
        servesAcp: false,
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnknown>());
      expect(result.runtimeVersion, "0.20.0");
    });

    test("uses an explicit --hermes-bin override for every probe", () async {
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("0.20.0\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 2,
            stdoutBytes: utf8.encode("Model: gpt-5.4\nProvider: openai\n"),
            stderrBytes: const [],
            exitCode: Future<int>.value(0),
          ),
        ],
        servesAcp: false,
      );

      final result = await const HermesPluginDescriptor().inspectSetup(
        config: const PluginConfig(values: {HermesPluginDescriptor.binOption: "/custom/hermes"}),
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady.versioned(runtimeVersion: "0.20.0"));
      expect(processes.spawnedExecutables, ["/custom/hermes", "/custom/hermes"]);
    });

    test("start spawns exactly one `hermes acp` process and connects", () async {
      const descriptor = HermesPluginDescriptor();
      final processes = _ProbeProcessService(
        spawnError: null,
        processSequence: const [],
        servesAcp: true,
      );

      final plugin = await descriptor.start(
        _StartPluginHost(
          processes: processes,
          config: config,
          provisionedRuntimePath: "/resolved/hermes",
        ),
      );

      expect(processes.spawnedExecutables, ["/resolved/hermes"]);
      expect(processes.spawnedArguments, [
        const ["acp"],
      ]);

      await plugin.shutdown(budget: null);
      expect(processes.gracefulSignals, [1]);
    });
  });
}

class _StartPluginHost({
  @override required final HostProcessService processes,
  @override required final PluginConfig config,
  @override required final String? provisionedRuntimePath,
}) implements PluginHost {
  @override
  Map<String, String> get environment => const {"HOME": "/tmp"};

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
  required final Object? spawnError,
  required final List<_ProbeProcess> processSequence,
  required final bool servesAcp,
}) implements HostProcessService {
  int _nextProcess = 0;
  _AcpProcess? _acpProcess;
  final List<String> spawnedExecutables = <String>[];
  final List<List<String>> spawnedArguments = <List<String>>[];
  final List<int> gracefulSignals = <int>[];

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
    if (servesAcp) {
      final process = _AcpProcess();
      _acpProcess = process;
      return process;
    }
    return processSequence[_nextProcess++];
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    gracefulSignals.add(pid);
    _acpProcess?.exit(-15);
    return _signal(
      pid: pid,
      requestedSignal: ShutdownSignal.graceful,
      deliveredSignal: ProcessSignal.sigterm,
    );
  }

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    _acpProcess?.exit(-9);
    return _signal(
      pid: pid,
      requestedSignal: ShutdownSignal.force,
      deliveredSignal: ProcessSignal.sigkill,
    );
  }

  SignalResult _signal({
    required int pid,
    required ShutdownSignal requestedSignal,
    required ProcessSignal deliveredSignal,
  }) => SignalResult(
    pid: pid,
    requestedSignal: requestedSignal,
    deliveredSignal: deliveredSignal,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 6, 1),
  );
}

/// A canned [SpawnedProcess] with fixed stdout/stderr payloads and a
/// caller-supplied [exitCode] future.
class _ProbeProcess({
  @override required final int pid,
  required final List<int> _stdoutBytes,
  required final List<int> _stderrBytes,
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

class _AcpProcess() implements SpawnedProcess {
  this {
    stdin = IOSink(_InputSink(onLine: _handleLine));
  }

  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final Completer<int> _exit = Completer<int>();

  @override
  late final IOSink stdin;

  void _handleLine(String line) {
    final frame = jsonDecode(line) as Map<String, dynamic>;
    if (frame["method"] == AcpMethods.authenticate) {
      _stdout.add(
        utf8.encode(
          "${jsonEncode({"jsonrpc": "2.0", "id": frame["id"], "result": <String, dynamic>{}})}\n",
        ),
      );
      return;
    }
    if (frame["method"] != AcpMethods.initialize) return;
    _stdout.add(
      utf8.encode(
        "${jsonEncode({
          "jsonrpc": "2.0",
          "id": frame["id"],
          "result": {
            "protocolVersion": 1,
            "agentCapabilities": <String, dynamic>{},
            "authMethods": [
              {
                "id": "opencode-go",
                "name": "Configured provider",
              },
              {
                "type": "terminal",
                "id": "hermes-setup",
                "name": "Configure Hermes provider",
              },
            ],
          },
        })}\n",
      ),
    );
  }

  void exit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
    if (!_stdout.isClosed) unawaited(_stdout.close());
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  ProcessIdentity get identity => throw UnimplementedError();

  @override
  int get pid => 1;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  Stream<List<int>> get stdout => _stdout.stream;
}

class _InputSink({required final void Function(String line) onLine}) implements StreamConsumer<List<int>> {
  final StringBuffer _buffer = StringBuffer();

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final bytes in stream) {
      _buffer.write(utf8.decode(bytes));
      final lines = _buffer.toString().split("\n");
      _buffer
        ..clear()
        ..write(lines.removeLast());
      lines.where((line) => line.isNotEmpty).forEach(onLine);
    }
  }

  @override
  Future<void> close() async {}
}
