import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:omp_plugin/omp_plugin.dart";
import "package:omp_plugin/src/api/omp_linux_libc_probe_api.dart";
import "package:omp_plugin/src/repositories/omp_runtime_asset_repository.dart";
import "package:omp_plugin/src/services/omp_runtime_asset_service.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

OmpRuntimeAssetService _runtimeAssets({
  required CommandExecutor commandExecutor,
  required Duration probeTimeout,
}) => OmpRuntimeAssetService(
  repository: OmpRuntimeAssetRepository(
    api: OmpLinuxLibcProbeApi(
      commandExecutor: commandExecutor,
      alpineMarkerPath: "/not-alpine",
      timeout: probeTimeout,
    ),
    manifest: const OmpRuntimeManifest(),
  ),
  manifest: const OmpRuntimeManifest(),
);

void main() {
  group("OmpPluginDescriptor.needsManagedRuntimeUpgrade", () {
    late Directory stateDir;

    setUp(() async {
      stateDir = await Directory.systemTemp.createTemp("omp-upgrade");
    });

    tearDown(() async {
      if (stateDir.existsSync()) await stateDir.delete(recursive: true);
    });

    void installedVersion(String version) {
      Directory("${stateDir.path}/${const OmpRuntimeManifest().runtimeId}/$version").createSync(recursive: true);
    }

    test("declines without a superseded managed runtime", () {
      installedVersion(const OmpRuntimeManifest().bundledVersion.raw);

      expect(
        OmpPluginDescriptor.production().needsManagedRuntimeUpgrade(
          config: const PluginConfig(values: {OmpPluginDescriptor.binOption: "omp"}),
          stateDirectory: stateDir.path,
        ),
        isFalse,
      );
    });

    test("asks for an upgrade when a superseded version is installed", () {
      installedVersion("17.3.0");

      expect(
        OmpPluginDescriptor.production().needsManagedRuntimeUpgrade(
          config: const PluginConfig(values: {OmpPluginDescriptor.binOption: "omp"}),
          stateDirectory: stateDir.path,
        ),
        isTrue,
      );
    });

    test("declines with an explicit binary override", () {
      installedVersion("17.3.0");

      expect(
        OmpPluginDescriptor.production().needsManagedRuntimeUpgrade(
          config: const PluginConfig(values: {OmpPluginDescriptor.binOption: "/custom/omp"}),
          stateDirectory: stateDir.path,
        ),
        isFalse,
      );
    });
  });

  const config = PluginConfig(values: {OmpPluginDescriptor.binOption: "omp"});

  group("OmpPluginDescriptor setup", () {
    test("declares narrow OMP capabilities while remaining registration-neutral", () {
      final descriptor = OmpPluginDescriptor.production();
      expect(descriptor.id, "omp");
      expect(descriptor.displayName, "Oh My Pi");
      expect(descriptor.projectOwnership, PluginProjectOwnership.bridgeDerived);
      expect(descriptor.sessionOptionsScope, PluginSessionOptionsScope.project);
      expect(descriptor.supportsPromptAttachments, isTrue);
      expect(descriptor.options.single.name, "bin");
    });

    test("ensureRuntime prefers a supported PATH binary", () async {
      final processes = _Processes(
        outputs: const [
          _Output(stdout: "omp/17.2.13\n", exitCode: 0),
        ],
      );
      final events = await OmpPluginDescriptor.production().ensureRuntime(host: _Host(processes: processes)).toList();

      expect((events.last as ProvisionReady).binaryPath, "omp");
      expect(processes.executables, ["omp"]);
    });

    test("ensureRuntime falls back to an installed managed binary", () async {
      final processes = _Processes(
        outputs: const [
          _Output(stdout: "omp/17.2.12\n", exitCode: 0),
          _Output(stdout: "omp/17.3.8\n", exitCode: 0),
        ],
      );
      final events = await OmpPluginDescriptor.production().ensureRuntime(host: _Host(processes: processes)).toList();

      expect((events.last as ProvisionReady).binaryPath, contains("/state/omp/17.3.8/omp"));
      expect(processes.executables, ["omp", contains("/state/omp/17.3.8/omp")]);
    });

    test("reports ready from the runtime and model listing probes without an ACP probe", () async {
      final processes = _Processes(
        outputs: const [
          _Output(stdout: "omp/17.3.8\n", exitCode: 0),
          _Output(stdout: '{"models":[{"provider":"deepseek","id":"deepseek-v4-flash"}]}', exitCode: 0),
        ],
      );
      final result = await OmpPluginDescriptor.production().inspectSetup(
        config: config,
        processes: processes,
        environment: const {"OMP_PROFILE": "work"},
        stateDirectory: "/state",
      );

      expect(result, const PluginSetupReady.versioned(runtimeVersion: "17.3.8"));
      expect(processes.arguments, [
        const ["--version"],
        const ["models", "--json"],
      ]);
      expect(processes.environments, everyElement(const {"OMP_PROFILE": "work"}));
    });

    test("reports an empty model listing as authentication required", () async {
      final result = await OmpPluginDescriptor.production().inspectSetup(
        config: config,
        processes: _Processes(
          outputs: const [
            _Output(stdout: "omp/17.3.8\n", exitCode: 0),
            _Output(stdout: '{"models":[]}', exitCode: 0),
          ],
        ),
        environment: const {},
        stateDirectory: "/state",
      );

      expect(
        result,
        isA<PluginSetupAuthenticationRequired>().having((s) => s.runtimeVersion, "runtimeVersion", "17.3.8"),
      );
    });

    test("leaves setup ready when the model listing is unparsable or fails", () async {
      final unparsable = await OmpPluginDescriptor.production().inspectSetup(
        config: config,
        processes: _Processes(
          outputs: const [
            _Output(stdout: "omp/17.3.8\n", exitCode: 0),
            _Output(stdout: "error: unknown flag --json\n", exitCode: 0),
          ],
        ),
        environment: const {},
        stateDirectory: "/state",
      );
      final failed = await OmpPluginDescriptor.production().inspectSetup(
        config: config,
        processes: _Processes(
          outputs: const [
            _Output(stdout: "omp/17.3.8\n", exitCode: 0),
            _Output(stdout: '{"models":[]}', exitCode: 2),
          ],
        ),
        environment: const {},
        stateDirectory: "/state",
      );

      expect(unparsable, const PluginSetupReady.versioned(runtimeVersion: "17.3.8"));
      expect(failed, const PluginSetupReady.versioned(runtimeVersion: "17.3.8"));
    });

    test("uses the shared token-based version parsing", () async {
      final result = await OmpPluginDescriptor.production().inspectSetup(
        config: config,
        processes: _Processes(
          outputs: const [
            _Output(stdout: "Oh My Pi omp/17.3.8 stable\n", exitCode: 0),
            _Output(stdout: '{"models":[{"id":"x"}]}', exitCode: 0),
          ],
        ),
        environment: const {},
        stateDirectory: "/state",
      );

      expect(result, const PluginSetupReady.versioned(runtimeVersion: "17.3.8"));
    });

    test("reports an installable missing runtime after PATH and managed probes", () async {
      final result = await OmpPluginDescriptor.production().inspectSetup(
        config: config,
        processes: _Processes(spawnError: const ProcessException("omp", ["--version"], "missing")),
        environment: const {},
        stateDirectory: "/state",
      );
      expect(result, isA<PluginSetupRuntimeMissing>());
    });

    test("explicit binary override is authoritative and disables install", () async {
      const explicit = PluginConfig(values: {OmpPluginDescriptor.binOption: "/custom/omp"});
      final descriptor = OmpPluginDescriptor.production();
      expect(
        descriptor.managementCapabilities(config: explicit),
        isNot(contains(PluginControlCapability.install)),
      );
      final result = await descriptor.inspectSetup(
        config: explicit,
        processes: _Processes(spawnError: const ProcessException("/custom/omp", ["--version"], "missing")),
        environment: const {},
        stateDirectory: "/state",
      );
      expect(result, isA<PluginSetupRuntimeMissing>());
    });

    test("classifies outdated and unrecognized explicit runtimes", () async {
      const explicit = PluginConfig(values: {OmpPluginDescriptor.binOption: "/custom/omp"});
      final descriptor = OmpPluginDescriptor.production();
      final outdated = await descriptor.inspectSetup(
        config: explicit,
        processes: _Processes(
          outputs: const [_Output(stdout: "omp/17.2.12\n", exitCode: 0)],
        ),
        environment: const {},
        stateDirectory: "/state",
      );
      final unknown = await descriptor.inspectSetup(
        config: explicit,
        processes: _Processes(
          outputs: const [_Output(stdout: "future format\n", exitCode: 0)],
        ),
        environment: const {},
        stateDirectory: "/state",
      );

      expect(outdated, isA<PluginSetupUnavailable>());
      expect(unknown, isA<PluginSetupUnknown>());
    });

    test("classifies non-process probe failures as unknown", () async {
      const explicit = PluginConfig(values: {OmpPluginDescriptor.binOption: "/custom/omp"});
      final result = await OmpPluginDescriptor.production().inspectSetup(
        config: explicit,
        processes: _Processes(spawnError: StateError("process service unavailable")),
        environment: const {},
        stateDirectory: "/state",
      );

      expect(result, isA<PluginSetupUnknown>());
    });
  });

  group("OmpPluginDescriptor lifecycle", () {
    test("starts through AcpBridgePlugin and preserves the host environment", () async {
      final processes = _Processes(acp: true);
      final host = _Host(processes: processes);
      final plugin = await OmpPluginDescriptor.production().start(host);

      expect(plugin, isA<AcpBridgePlugin>());
      expect(processes.executables.single, "omp");
      expect(processes.arguments.single, ["acp"]);
      expect(processes.environments.single, const {
        "OMP_PROFILE": "work",
        "PI_CODING_AGENT_DIR": "/profile",
      });
      await plugin.shutdown(budget: null);
      expect(processes.gracefulSignals, [1]);
    });

    test("starts degraded when the ACP handshake cannot connect", () async {
      final descriptor = OmpPluginDescriptor(
        buildPlugin:
            ({
              required binaryPath,
              required launchDirectory,
              required scratchDirectory,
              required processFactory,
            }) => OmpPlugin(
              binaryPath: binaryPath,
              launchDirectory: launchDirectory,
              scratchDirectory: scratchDirectory,
              processFactory: (_) async => throw StateError("connection failed"),
            ),
        buildRuntimeAssetService: _runtimeAssets,
        connectBudget: const Duration(milliseconds: 20),
        versionProbeTimeout: const Duration(seconds: 1),
      );
      final plugin = await descriptor.start(
        _Host(processes: _Processes(), clock: const _ImmediateClock()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(plugin.currentStatus, isA<PluginDegraded>());
      await plugin.shutdown(budget: null);
    });

    test("recovers from degraded after a later successful ACP connection", () async {
      final process = FakeAcpProcess();
      var attempts = 0;
      final descriptor = OmpPluginDescriptor(
        buildPlugin:
            ({
              required binaryPath,
              required launchDirectory,
              required scratchDirectory,
              required processFactory,
            }) => OmpPlugin(
              binaryPath: binaryPath,
              launchDirectory: launchDirectory,
              scratchDirectory: scratchDirectory,
              processFactory: (_) async {
                if (attempts++ == 0) throw StateError("connection failed");
                return process;
              },
            ),
        buildRuntimeAssetService: _runtimeAssets,
        connectBudget: const Duration(milliseconds: 20),
        versionProbeTimeout: const Duration(seconds: 1),
      );
      final plugin = await descriptor.start(
        _Host(processes: _Processes(), clock: const _ImmediateClock()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(plugin.currentStatus, isA<PluginDegraded>());

      final reconnecting = plugin.api.healthCheck();
      final initialize = await _waitForFrame(process: process, method: AcpMethods.initialize);
      process.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": [
            {"id": "agent", "name": "Agent"},
          ],
        },
      });
      final authenticate = await _waitForFrame(process: process, method: AcpMethods.authenticate);
      process.emit({"jsonrpc": "2.0", "id": authenticate["id"], "result": <String, dynamic>{}});
      await reconnecting;
      await Future<void>.delayed(Duration.zero);

      expect(plugin.currentStatus, isA<PluginReady>());
      await plugin.shutdown(budget: null);
      await process.close();
    });

    test("rolls back when start aborts during ACP connect", () async {
      final controller = StartAbortController();
      final processes = _Processes(acp: true, onInitialize: controller.abort);
      final host = _Host(processes: processes, startAborted: controller.signal);

      await expectLater(
        OmpPluginDescriptor.production().start(host),
        throwsA(isA<PluginStartAbortedException>()),
      );
      expect(processes.gracefulSignals, [1]);
    });
  });
}

Future<Map<String, dynamic>> _waitForFrame({
  required FakeAcpProcess process,
  required String method,
}) async {
  for (var i = 0; i < 200; i++) {
    for (final frame in process.written) {
      if (frame["method"] == method) return frame;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError("OMP never wrote '$method'");
}

class _Host({
  @override required final HostProcessService processes,
  StartAbortSignal? startAborted,
  @override final ServerClock clock = const ServerClock(),
}) implements PluginHost {
  @override
  final StartAbortSignal startAborted = startAborted ?? StartAbortSignal.never;

  @override
  PluginConfig get config => const PluginConfig(values: {OmpPluginDescriptor.binOption: "omp"});

  @override
  Map<String, String> get environment => const {
    "OMP_PROFILE": "work",
    "PI_CODING_AGENT_DIR": "/profile",
  };

  @override
  String? get provisionedRuntimePath => null;

  @override
  String get stateDirectory => "/state";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _ImmediateClock() extends ServerClock {
  @override
  Future<void> delay({required Duration duration}) async {}
}

class const _Output({required final String stdout, required final int exitCode});

class _Processes({
  final List<_Output> outputs = const [],
  final Object? spawnError,
  final bool acp = false,
  final void Function()? onInitialize,
}) implements HostProcessService {
  final List<String> executables = [];
  final List<List<String>> arguments = [];
  final List<Map<String, String>?> environments = [];
  final List<int> gracefulSignals = [];
  int _index = 0;
  _AcpProcess? _acpProcess;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    executables.add(executable);
    this.arguments.add(arguments);
    environments.add(environment);
    if (spawnError case final error?) throw error;
    if (acp) {
      final process = _AcpProcess(onInitialize: onInitialize);
      _acpProcess = process;
      return process;
    }
    final output = outputs[_index++];
    return _ProbeProcess(output: output);
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    _acpProcess?.exit(-9);
    return _signal(pid: pid, signal: ShutdownSignal.force, delivered: ProcessSignal.sigkill);
  }

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    gracefulSignals.add(pid);
    _acpProcess?.exit(-15);
    return _signal(pid: pid, signal: ShutdownSignal.graceful, delivered: ProcessSignal.sigterm);
  }

  SignalResult _signal({
    required int pid,
    required ShutdownSignal signal,
    required ProcessSignal delivered,
  }) => SignalResult(
    pid: pid,
    requestedSignal: signal,
    deliveredSignal: delivered,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 8, 13),
  );
}

class _ProbeProcess({required _Output output}) implements SpawnedProcess {
  @override
  final Stream<List<int>> stdout = Stream.value(utf8.encode(output.stdout));

  @override
  final Future<int> exitCode = Future.value(output.exitCode);

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  int get pid => 1;

  @override
  ProcessIdentity get identity => throw UnimplementedError();

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);
}

class _AcpProcess({required final void Function()? onInitialize}) implements SpawnedProcess {
  this {
    stdin = IOSink(_InputSink(onLine: _handleLine));
  }

  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final Completer<int> _exit = Completer<int>();

  @override
  late final IOSink stdin;

  void _handleLine(String line) {
    final frame = jsonDecode(line) as Map<String, dynamic>;
    final id = frame["id"];
    if (frame["method"] == AcpMethods.initialize) {
      onInitialize?.call();
      _emit({
        "jsonrpc": "2.0",
        "id": id,
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": [
            {"id": "agent", "name": "Agent"},
          ],
        },
      });
    } else if (frame["method"] == AcpMethods.authenticate) {
      _emit({"jsonrpc": "2.0", "id": id, "result": <String, dynamic>{}});
    }
  }

  void _emit(Map<String, dynamic> frame) => _stdout.add(utf8.encode("${jsonEncode(frame)}\n"));

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
      final text = _buffer.toString();
      final lines = text.split("\n");
      _buffer
        ..clear()
        ..write(lines.removeLast());
      lines.where((line) => line.isNotEmpty).forEach(onLine);
    }
  }

  @override
  Future<void> close() async {}
}
