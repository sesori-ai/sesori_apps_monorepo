import "dart:async";
import "dart:convert";
import "dart:io";

import "package:pi_plugin/pi_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("PiPluginDescriptor setup", () {
    test("declares Pi capabilities without registering it", () {
      final descriptor = PiPluginDescriptor.production();
      const config = PluginConfig(values: {PiPluginDescriptor.binOption: null});

      expect(descriptor.id, "pi");
      expect(descriptor.displayName, "Pi");
      expect(descriptor.projectOwnership, PluginProjectOwnership.bridgeDerived);
      expect(descriptor.sessionOptionsScope, PluginSessionOptionsScope.project);
      expect(descriptor.supportsPromptAttachments, isTrue);
      expect(descriptor.residencyPolicy(config: config), PluginResidencyPolicy.resident);
      expect(
        descriptor.managementCapabilities(config: config),
        contains(PluginControlCapability.idleTimeout),
      );
      expect(descriptor.options.single.name, "bin");
      expect((descriptor.options.single as PluginValueOption).defaultsTo, isNull);
    });

    test("ensureRuntime prefers a supported PATH binary", () async {
      final processes = _Processes(outputs: const [_Output(stdout: "0.84.2\n", exitCode: 0)]);
      final events = await PiPluginDescriptor.production().ensureRuntime(host: _Host(processes: processes)).toList();

      expect((events.last as ProvisionReady).binaryPath, "pi");
      expect(processes.executables, ["pi"]);
    });

    test("ensureRuntime falls back to the exact managed binary", () async {
      final processes = _Processes(
        outputs: const [
          _Output(stdout: "0.84.1\n", exitCode: 0),
          _Output(stdout: "0.84.2\n", exitCode: 0),
        ],
      );
      final events = await PiPluginDescriptor.production().ensureRuntime(host: _Host(processes: processes)).toList();

      expect((events.last as ProvisionReady).binaryPath, contains("/state/pi/0.84.2/pi"));
      expect(processes.executables, ["pi", contains("/state/pi/0.84.2/pi")]);
    });

    test("inspectSetup checks only version and preserves the environment", () async {
      final processes = _Processes(outputs: const [_Output(stdout: "pi 0.84.2\n", exitCode: 0)]);
      final result = await PiPluginDescriptor.production().inspectSetup(
        config: const PluginConfig(values: {PiPluginDescriptor.binOption: "pi"}),
        processes: processes,
        environment: const {"PI_CODING_AGENT_DIR": "/profile"},
        stateDirectory: "/state",
      );

      expect(result, const PluginSetupReady());
      expect(processes.arguments, [
        const ["--version"],
      ]);
      expect(processes.environments.single, const {"PI_CODING_AGENT_DIR": "/profile"});
    });

    test("explicit binary is authoritative and classifies setup failures", () async {
      const config = PluginConfig(values: {PiPluginDescriptor.binOption: "/custom/pi"});
      final descriptor = PiPluginDescriptor.production();
      expect(descriptor.managementCapabilities(config: config), isNot(contains(PluginControlCapability.install)));
      expect(
        await descriptor
            .ensureRuntime(
              host: _Host(processes: _Processes(), config: config),
            )
            .toList(),
        isEmpty,
      );

      final missing = await descriptor.inspectSetup(
        config: config,
        processes: _Processes(spawnError: const ProcessException("/custom/pi", ["--version"], "missing")),
        environment: const {},
        stateDirectory: "/state",
      );
      final outdated = await descriptor.inspectSetup(
        config: config,
        processes: _Processes(outputs: const [_Output(stdout: "0.84.0\n", exitCode: 0)]),
        environment: const {},
        stateDirectory: "/state",
      );
      final unknown = await descriptor.inspectSetup(
        config: config,
        processes: _Processes(outputs: const [_Output(stdout: "future\n", exitCode: 0)]),
        environment: const {},
        stateDirectory: "/state",
      );

      expect(missing, isA<PluginSetupRuntimeMissing>());
      expect(outdated, isA<PluginSetupUnavailable>());
      expect(unknown, isA<PluginSetupUnknown>());
    });

    test("an explicit PATH name remains authoritative and disables managed resolution", () async {
      const config = PluginConfig(values: {PiPluginDescriptor.binOption: "pi"});
      final descriptor = PiPluginDescriptor.production();

      expect(descriptor.managementCapabilities(config: config), isNot(contains(PluginControlCapability.install)));
      expect(
        await descriptor
            .ensureRuntime(
              host: _Host(processes: _Processes(), config: config),
            )
            .toList(),
        isEmpty,
      );
    });
  });

  group("PiPluginDescriptor lifecycle", () {
    test("starts ready with the resolved binary and separates launch overrides", () async {
      String? capturedBinaryPath;
      Map<String, String>? capturedStorageEnvironment;
      Map<String, String>? capturedProcessEnvironment;
      Duration? Function()? capturedIdleTimeoutResolver;
      PluginAgentToolServices? capturedAgentToolServices;
      final descriptor = _descriptor(
        buildPlugin:
            ({
              required binaryPath,
              required storageEnvironment,
              required processEnvironment,
              required processFactory,
              required commandExecutor,
              required clock,
              required launchDirectory,
              required startupExitTimeout,
              required historyRpcTimeout,
              required catalogTimeout,
              required healthTimeout,
              required resolveIdleTimeout,
              required editorTimeout,
              required agentToolServices,
            }) {
              capturedBinaryPath = binaryPath;
              capturedStorageEnvironment = storageEnvironment;
              capturedProcessEnvironment = processEnvironment;
              capturedIdleTimeoutResolver = resolveIdleTimeout;
              capturedAgentToolServices = agentToolServices;
              return _plugin(
                binaryPath: binaryPath,
                storageEnvironment: storageEnvironment,
                processEnvironment: processEnvironment,
                processFactory: processFactory,
                commandExecutor: commandExecutor,
                clock: clock,
                launchDirectory: launchDirectory,
                startupExitTimeout: startupExitTimeout,
                historyRpcTimeout: historyRpcTimeout,
                catalogTimeout: catalogTimeout,
                healthTimeout: healthTimeout,
                resolveIdleTimeout: resolveIdleTimeout,
                editorTimeout: editorTimeout,
                agentToolServices: agentToolServices,
              );
            },
      );
      final agentToolServices = _AgentToolServices();
      final host = _Host(
        processes: _Processes(),
        provisionedRuntimePath: "/managed/pi",
        pluginIdleTimeout: const Duration(minutes: 17),
        agentToolServices: agentToolServices,
      );
      final plugin = await descriptor.start(host);

      expect(capturedBinaryPath, "/managed/pi");
      expect(capturedStorageEnvironment, containsPair("HOME", "/home/test"));
      expect(capturedProcessEnvironment, isEmpty);
      expect(capturedIdleTimeoutResolver?.call(), const Duration(minutes: 17));
      expect(capturedAgentToolServices, same(agentToolServices));
      expect(plugin.currentStatus, const PluginReady());
      expect(plugin.currentWorkState, PluginWorkState.idle);

      await plugin.shutdown(budget: null);
      expect(plugin.currentStatus, const PluginStopped());
      expect(await plugin.api.healthCheck(), isFalse);
    });

    test("rolls back a plugin built while start becomes aborted", () async {
      final abort = StartAbortController();
      PiPlugin? built;
      final descriptor = _descriptor(
        buildPlugin:
            ({
              required binaryPath,
              required storageEnvironment,
              required processEnvironment,
              required processFactory,
              required commandExecutor,
              required clock,
              required launchDirectory,
              required startupExitTimeout,
              required historyRpcTimeout,
              required catalogTimeout,
              required healthTimeout,
              required resolveIdleTimeout,
              required editorTimeout,
              required agentToolServices,
            }) {
              built = _plugin(
                binaryPath: binaryPath,
                storageEnvironment: storageEnvironment,
                processEnvironment: processEnvironment,
                processFactory: processFactory,
                commandExecutor: commandExecutor,
                clock: clock,
                launchDirectory: launchDirectory,
                startupExitTimeout: startupExitTimeout,
                historyRpcTimeout: historyRpcTimeout,
                catalogTimeout: catalogTimeout,
                healthTimeout: healthTimeout,
                resolveIdleTimeout: resolveIdleTimeout,
                editorTimeout: editorTimeout,
                agentToolServices: agentToolServices,
              );
              abort.abort();
              return built!;
            },
      );

      await expectLater(
        descriptor.start(_Host(processes: _Processes(), startAborted: abort.signal)),
        throwsA(isA<PluginStartAbortedException>()),
      );
      expect(await built!.healthCheck(), isFalse);
    });

    test("host process factory launches every session with approval and managed update suppression", () async {
      final processes = _Processes(outputs: const [_Output(stdout: "", exitCode: 0)]);
      final factory = HostPiProcessFactory(processes: processes);
      final process = await factory.spawn(
        spec: PiLaunchSpec(
          binaryPath: "/managed/pi",
          workingDirectory: "/project",
          launch: const PiNoSession(),
          model: null,
          thinkingLevel: null,
          environment: const {"ANTHROPIC_API_KEY": "secret"},
        ),
      );

      expect(processes.executables, ["/managed/pi"]);
      expect(processes.arguments.single, ["--mode", "rpc", "--no-session", "--approve"]);
      expect(processes.environments.single, {
        "ANTHROPIC_API_KEY": "secret",
        "PI_SKIP_VERSION_CHECK": "1",
      });
      process.kill(signal: ProcessSignal.sigterm);
      expect(processes.gracefulSignals, [1]);
      await factory.dispose();
    });
  });
}

PiPluginDescriptor _descriptor({required PiPluginFactory buildPlugin}) => PiPluginDescriptor(
  buildPlugin: buildPlugin,
  versionProbeTimeout: const Duration(seconds: 1),
  statusDebounce: Duration.zero,
);

PiPlugin _plugin({
  required String binaryPath,
  required Map<String, String> storageEnvironment,
  required Map<String, String> processEnvironment,
  required PiProcessFactory processFactory,
  required CommandExecutor commandExecutor,
  required ServerClock clock,
  required String launchDirectory,
  required Duration startupExitTimeout,
  required Duration historyRpcTimeout,
  required Duration catalogTimeout,
  required Duration healthTimeout,
  required Duration? Function() resolveIdleTimeout,
  required Duration editorTimeout,
  PluginAgentToolServices? agentToolServices,
}) => PiPlugin(
  binaryPath: binaryPath,
  storageEnvironment: storageEnvironment,
  processEnvironment: processEnvironment,
  processFactory: processFactory,
  commandExecutor: commandExecutor,
  clock: clock,
  launchDirectory: launchDirectory,
  startupExitTimeout: startupExitTimeout,
  historyRpcTimeout: historyRpcTimeout,
  catalogTimeout: catalogTimeout,
  healthTimeout: healthTimeout,
  resolveIdleTimeout: resolveIdleTimeout,
  editorTimeout: editorTimeout,
  agentToolServices: agentToolServices,
);

class _Host({
  @override required final HostProcessService processes,
  @override final PluginConfig config = const PluginConfig(values: {PiPluginDescriptor.binOption: null}),
  @override final String? provisionedRuntimePath,
  @override final Duration? pluginIdleTimeout = const Duration(minutes: 10),
  StartAbortSignal? startAborted,
  @override final PluginAgentToolServices? agentToolServices,
}) implements PluginHost, PluginAgentToolServicesProvider {
  @override
  final StartAbortSignal startAborted = startAborted ?? StartAbortSignal.never;

  @override
  Map<String, String> get environment => const {"HOME": "/home/test", "PI_CODING_AGENT_DIR": "/profile"};

  @override
  ServerClock get clock => const ServerClock();

  @override
  String get stateDirectory => "/state";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _AgentToolServices() implements PluginAgentToolServices {
  @override
  final PluginPrivateFileService privateFiles = _UnusedPrivateFiles();

  @override
  final PluginAgentToolHost tools = _UnusedAgentTools();
}

final class _UnusedPrivateFiles() implements PluginPrivateFileService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedAgentTools() implements PluginAgentToolHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _Output({required final String stdout, required final int exitCode});

class _Processes({
  final List<_Output> outputs = const [],
  final Object? spawnError,
}) implements HostProcessService {
  final List<String> executables = [];
  final List<List<String>> arguments = [];
  final List<Map<String, String>?> environments = [];
  final List<int> gracefulSignals = [];
  int _index = 0;

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
    return _ProbeProcess(output: outputs[_index++]);
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalForce({required int pid}) async => _signal(
    pid: pid,
    signal: ShutdownSignal.force,
    delivered: ProcessSignal.sigkill,
  );

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    gracefulSignals.add(pid);
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
    attemptedAt: DateTime.utc(2026, 8, 15),
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
