import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("DeepSeekPluginDescriptor.needsManagedRuntimeUpgrade", () {
    late Directory stateDir;

    setUp(() async {
      stateDir = await Directory.systemTemp.createTemp("deepseek-upgrade");
    });

    tearDown(() async {
      if (stateDir.existsSync()) await stateDir.delete(recursive: true);
    });

    void installedVersion(String version) {
      Directory("${stateDir.path}/${const DeepSeekRuntimeManifest().runtimeId}/$version").createSync(recursive: true);
    }

    test("declines without a superseded managed runtime", () {
      installedVersion(const DeepSeekRuntimeManifest().bundledVersion.raw);

      expect(
        const DeepSeekPluginDescriptor().needsManagedRuntimeUpgrade(
          config: const PluginConfig(values: {DeepSeekPluginDescriptor.binOption: DeepSeekBinary.defaultBinary}),
          stateDirectory: stateDir.path,
        ),
        isFalse,
      );
    });

    test("asks for an upgrade when a superseded version is installed", () {
      installedVersion("0.1.2");

      expect(
        const DeepSeekPluginDescriptor().needsManagedRuntimeUpgrade(
          config: const PluginConfig(values: {DeepSeekPluginDescriptor.binOption: DeepSeekBinary.defaultBinary}),
          stateDirectory: stateDir.path,
        ),
        isTrue,
      );
    });

    test("declines with an explicit binary override", () {
      installedVersion("0.1.2");

      expect(
        const DeepSeekPluginDescriptor().needsManagedRuntimeUpgrade(
          config: const PluginConfig(values: {DeepSeekPluginDescriptor.binOption: "/custom/deepseek"}),
          stateDirectory: stateDir.path,
        ),
        isFalse,
      );
    });
  });

  const config = PluginConfig(values: {DeepSeekPluginDescriptor.binOption: DeepSeekBinary.defaultBinary});

  test("descriptor declares managed installation when no explicit path is configured", () {
    const descriptor = DeepSeekPluginDescriptor();
    expect([descriptor.id, descriptor.displayName], ["deepseek", "DeepSeek"]);
    expect(descriptor.projectOwnership, PluginProjectOwnership.bridgeDerived);
    expect(descriptor.sessionOptionsScope, PluginSessionOptionsScope.plugin);
    expect(descriptor.supportsPromptAttachments, isTrue);
    expect(descriptor.options.map((option) => option.name), [DeepSeekPluginDescriptor.binOption]);
    expect(descriptor.managementCapabilities(config: config), contains(PluginControlCapability.install));
  });

  test("ensureRuntime accepts a supported explicit adapter", () async {
    const explicitConfig = PluginConfig(values: {DeepSeekPluginDescriptor.binOption: "/custom/deepseek"});
    expect(
      const DeepSeekPluginDescriptor().managementCapabilities(config: explicitConfig),
      isNot(contains(PluginControlCapability.install)),
    );
    final processes = _ProcessService(
      probes: [
        _ProbeProcess(
          pid: 1,
          stdoutBytes: utf8.encode(
            "sesori-deepseek-acp/${DeepSeekPluginDescriptor.targetVersion} deepseek-harness/0.1.1-rc.2 acp/1\n",
          ),
          stderrBytes: const [],
          exitCodeValue: 0,
        ),
      ],
    );
    final events = await const DeepSeekPluginDescriptor()
        .ensureRuntime(
          host: _PluginHost(
            processes: processes,
            config: explicitConfig,
            provisionedRuntimePath: null,
          ),
        )
        .toList();

    expect(events.last, isA<ProvisionReady>().having((event) => event.binaryPath, "binaryPath", "/custom/deepseek"));
    expect(processes.spawnedArguments, [
      const ["--version"],
    ]);
  });

  test("setup inspection runs side-effect-free version and readiness probes", () async {
    final processes = _ProcessService(
      probes: [
        _ProbeProcess(
          pid: 1,
          stdoutBytes: utf8.encode(
            "sesori-deepseek-acp/${DeepSeekPluginDescriptor.targetVersion} deepseek-harness/0.1.1-rc.2 acp/1\n",
          ),
          stderrBytes: const [],
          exitCodeValue: 0,
        ),
        _ProbeProcess(
          pid: 2,
          stdoutBytes: utf8.encode('{"status":"ok"}\n'),
          stderrBytes: const [],
          exitCodeValue: 0,
        ),
      ],
    );

    final result = await const DeepSeekPluginDescriptor().inspectSetup(
      config: config,
      processes: processes,
      environment: const {"TOKEN": "secret"},
      stateDirectory: "/state",
    );

    expect(result, const PluginSetupReady.versioned(runtimeVersion: DeepSeekPluginDescriptor.targetVersion));
    expect(processes.spawnedArguments, [
      const ["--version"],
      const ["check", "--state-dir", "/state"],
    ]);
  });

  test("setup distinguishes missing, outdated, and unknown adapters", () async {
    final missing = _ProcessService(spawnError: const ProcessException("deepseek", [], "not found", 2));
    expect(
      await const DeepSeekPluginDescriptor().inspectSetup(
        config: config,
        processes: missing,
        environment: const {},
        stateDirectory: "/state",
      ),
      isA<PluginSetupRuntimeMissing>(),
    );

    final outdated = _ProcessService(
      probes: [
        _ProbeProcess(
          pid: 1,
          stdoutBytes: utf8.encode("sesori-deepseek-acp/0.1.2 deepseek-harness/0.1.1-rc.2 acp/1\n"),
          stderrBytes: const [],
          exitCodeValue: 0,
        ),
      ],
    );
    expect(
      await const DeepSeekPluginDescriptor().inspectSetup(
        config: const PluginConfig(values: {DeepSeekPluginDescriptor.binOption: "/custom/deepseek"}),
        processes: outdated,
        environment: const {},
        stateDirectory: "/state",
      ),
      isA<PluginSetupUnavailable>(),
    );

    final unknown = _ProcessService(
      probes: [
        _ProbeProcess(
          pid: 1,
          stdoutBytes: utf8.encode("unrecognized\n"),
          stderrBytes: const [],
          exitCodeValue: 0,
        ),
      ],
    );
    expect(
      await const DeepSeekPluginDescriptor().inspectSetup(
        config: const PluginConfig(values: {DeepSeekPluginDescriptor.binOption: "/custom/deepseek"}),
        processes: unknown,
        environment: const {},
        stateDirectory: "/state",
      ),
      isA<PluginSetupUnknown>(),
    );
  });

  test("ensureRuntime replaces a protocol-v1 PATH adapter with the exact managed release", () async {
    final processes = _ProcessService(
      probes: [
        _ProbeProcess(
          pid: 1,
          stdoutBytes: utf8.encode("sesori-deepseek-acp/0.1.2 deepseek-harness/0.1.1-rc.2 acp/1\n"),
          stderrBytes: const [],
          exitCodeValue: 0,
        ),
        _ProbeProcess(
          pid: 2,
          stdoutBytes: utf8.encode(
            "sesori-deepseek-acp/${DeepSeekPluginDescriptor.targetVersion} deepseek-harness/0.1.1-rc.2 acp/1\n",
          ),
          stderrBytes: const [],
          exitCodeValue: 0,
        ),
      ],
    );

    final events = await const DeepSeekPluginDescriptor()
        .ensureRuntime(
          host: _PluginHost(processes: processes, config: config, provisionedRuntimePath: null),
        )
        .toList();

    expect(
      (events.last as ProvisionReady).binaryPath,
      contains("/state/deepseek/${DeepSeekPluginDescriptor.targetVersion}/sesori-deepseek-acp"),
    );
    expect(processes.spawnedExecutables.first, DeepSeekBinary.defaultBinary);
  });

  test("production composition exposes options and rename then recovers after a crash", () async {
    final processes = _ProcessService(serveAcp: true);
    final plugin = await const DeepSeekPluginDescriptor().start(
      _PluginHost(processes: processes, config: config, provisionedRuntimePath: "/resolved/deepseek"),
    );

    expect(plugin.currentStatus, isA<PluginReady>());
    final options = await plugin.api.getSessionOptions(
      projectId: Directory.current.path,
      discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
    );
    expect(options, isA<PluginSessionOptionsDiscoveryObserved>());
    final observed = options as PluginSessionOptionsDiscoveryObserved;
    expect(observed.options.providers.providers.single.models.single.id, "v1c3ludGhldGlj");
    final renamed = await plugin.api.renameSession(sessionId: "session-1", title: " requested ");
    expect(renamed.title, "Normalized title");

    processes.acpProcesses.single.exit(1);
    await _waitFor(() => plugin.currentStatus is PluginDegraded);
    expect(await plugin.api.healthCheck(), isTrue);
    await _waitFor(() => plugin.currentStatus is PluginReady);
    expect(processes.acpProcesses, hasLength(2));

    await plugin.shutdown(budget: null);
    await plugin.shutdown(budget: null);
    expect(processes.gracefulSignals, [100, 101]);
    expect(processes.spawnedExecutables.where((value) => value == "/resolved/deepseek"), hasLength(2));
    expect(
      processes.spawnedArguments.where((value) => value.first == "serve"),
      everyElement([
        "serve",
        "--state-dir",
        "/state",
      ]),
    );
  });

  test("missing extension metadata leaves production composition degraded", () async {
    final processes = _ProcessService(serveAcp: true, omitInitializeMetadata: true);
    final plugin = await const DeepSeekPluginDescriptor().start(
      _PluginHost(processes: processes, config: config, provisionedRuntimePath: "/resolved/deepseek"),
    );

    await _waitFor(() => plugin.currentStatus is PluginDegraded);
    await plugin.shutdown(budget: null);
  });
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 600; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError("condition was not reached");
}

class _PluginHost({
  @override required final HostProcessService processes,
  @override required final PluginConfig config,
  @override required final String? provisionedRuntimePath,
}) implements PluginHost {
  @override
  Map<String, String> get environment => const {"HOME": "/tmp"};

  @override
  String get stateDirectory => "/state";

  @override
  ServerClock get clock => const _ImmediateClock();

  @override
  StartAbortSignal get startAborted => StartAbortSignal.never;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _ImmediateClock() extends ServerClock {
  @override
  Future<void> delay({required Duration duration}) async {}
}

class _ProcessService({
  final List<_ProbeProcess> probes = const [],
  final Object? spawnError,
  final bool serveAcp = false,
  final bool omitInitializeMetadata = false,
}) implements HostProcessService {
  int _nextProbe = 0;
  int _nextAcpPid = 100;
  final List<_AcpProcess> acpProcesses = [];
  final List<String> spawnedExecutables = [];
  final List<List<String>> spawnedArguments = [];
  final List<int> gracefulSignals = [];

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    spawnedExecutables.add(executable);
    spawnedArguments.add(List.of(arguments));
    if (spawnError case final error?) throw error;
    if (serveAcp && arguments.isNotEmpty && arguments.first == "serve") {
      final process = _AcpProcess(pid: _nextAcpPid++, omitInitializeMetadata: omitInitializeMetadata);
      acpProcesses.add(process);
      return process;
    }
    if (_nextProbe < probes.length) return probes[_nextProbe++];
    throw StateError("No canned process remains");
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    gracefulSignals.add(pid);
    acpProcesses.where((process) => process.pid == pid).firstOrNull?.exit(-15);
    return _signal(pid: pid, requested: ShutdownSignal.graceful, delivered: ProcessSignal.sigterm);
  }

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    acpProcesses.where((process) => process.pid == pid).firstOrNull?.exit(-9);
    return _signal(pid: pid, requested: ShutdownSignal.force, delivered: ProcessSignal.sigkill);
  }

  SignalResult _signal({
    required int pid,
    required ShutdownSignal requested,
    required ProcessSignal delivered,
  }) => SignalResult(
    pid: pid,
    requestedSignal: requested,
    deliveredSignal: delivered,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 8, 24),
  );
}

class _ProbeProcess({
  @override required final int pid,
  required final List<int> stdoutBytes,
  required final List<int> stderrBytes,
  required final int exitCodeValue,
}) implements SpawnedProcess {
  @override
  Stream<List<int>> get stdout => Stream.value(stdoutBytes);

  @override
  Stream<List<int>> get stderr => Stream.value(stderrBytes);

  @override
  Future<int> get exitCode => Future.value(exitCodeValue);

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  ProcessIdentity get identity => throw UnimplementedError();
}

class _AcpProcess({@override required final int pid, required final bool omitInitializeMetadata})
    implements SpawnedProcess {
  this {
    stdin = IOSink(_InputSink(onLine: _handleLine));
  }

  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final Completer<int> _exit = Completer<int>();

  @override
  late final IOSink stdin;

  void _handleLine(String line) {
    final request = jsonDecode(line) as Map<String, dynamic>;
    final method = request["method"];
    final Object result = switch (method) {
      AcpMethods.initialize => {
        "protocolVersion": 1,
        "agentCapabilities": {
          "promptCapabilities": {"image": true},
          "sessionCapabilities": {"list": <String, dynamic>{}, "close": <String, dynamic>{}},
          "loadSession": true,
        },
        "authMethods": <Object>[],
        if (!omitInitializeMetadata)
          "_meta": {
            "sesori.ai/deepseek": {
              "extensionProtocolVersion": 2,
              "adapterVersion": DeepSeekPluginDescriptor.targetVersion,
              "harnessVersion": "0.1.1-rc.2",
              "persistenceOwner": "sesori",
            },
          },
      },
      DeepSeekAcpApi.catalogMethod => {
        "agent": {"id": "deepseek", "name": "DeepSeek", "primary": true},
        "providers": [
          {
            "id": "provider/alpha-α",
            "name": "Synthetic Provider",
            "models": [
              {
                "id": "v1c3ludGhldGlj",
                "upstreamModelId": "model/alpha-α",
                "name": "Synthetic Model",
                "reasoningEfforts": ["low", "high"],
                "defaultReasoningEffort": "low",
                "supportsImages": true,
              },
            ],
          },
        ],
        "defaultSelectionId": "v1c3ludGhldGlj",
        "commands": [
          {"name": "inspect", "description": "Inspect project"},
        ],
        "failures": <Object>[],
      },
      DeepSeekAcpApi.renameMethod => {"title": "Normalized title"},
      _ => <String, dynamic>{},
    };
    _stdout.add(utf8.encode("${jsonEncode({"jsonrpc": "2.0", "id": request["id"], "result": result})}\n"));
  }

  void exit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
    if (!_stdout.isClosed) unawaited(_stdout.close());
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  ProcessIdentity get identity => throw UnimplementedError();
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
