import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_testing.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _target = PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64);

class _Store({required final _Store? parent}) implements HostJsonStore {
  final scopes = <String>[];
  final writes = <String, String>{};

  _Store get _root => parent ?? this;

  @override
  HostJsonStore scope({required String directoryName}) {
    _root.scopes.add(directoryName);
    return _Store(parent: _root);
  }

  @override
  Future<void> write({required String name, required String contents}) async {
    _root.writes[name] = contents;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HelperProcess() implements SpawnedProcess {
  @override
  int get pid => 1;
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode async => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AgentInput({
  required final FakeAcpProcess process,
  required final Map<String, dynamic> initialize,
  required final bool respondToInitialize,
}) extends CapturingIOSink {
  @override
  void add(List<int> data) {
    super.add(data);
    final frame = frames.last;
    switch (frame["method"]) {
      case "initialize":
        if (respondToInitialize) {
          process.emit({"jsonrpc": "2.0", "id": frame["id"], "result": initialize});
        }
      case "authenticate":
        expect((frame["params"] as Map<String, dynamic>)["methodId"], AntigravityRelease.personalOauthMethodId);
        process.emit({"jsonrpc": "2.0", "id": frame["id"], "result": <String, dynamic>{}});
      default:
        fail("Descriptor startup must not create a session: ${frame["method"]}");
    }
  }
}

class _AgentProcess({
  required final Map<String, dynamic> initialize,
  required final bool respondToInitialize,
  @override required final int pid,
}) implements SpawnedProcess {
  final FakeAcpProcess process = FakeAcpProcess();
  @override
  late final stdin = _AgentInput(
    process: process,
    initialize: initialize,
    respondToInitialize: respondToInitialize,
  );
  @override
  Stream<List<int>> get stdout => process.stdout;
  @override
  Stream<List<int>> get stderr => process.stderr;
  @override
  Future<int> get exitCode => process.exitCode;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Launch({
  required final String executable,
  required final List<String> arguments,
  required final Map<String, String> environment,
  required final String? workingDirectory,
  required final bool includeParentEnvironment,
});

class _Processes({
  required final String serverPath,
  required final Map<String, dynamic> initialize,
  required final bool respondToInitialize,
}) implements HostProcessService {
  final launches = <_Launch>[];
  final agents = <_AgentProcess>[];

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) async {
    launches.add(
      _Launch(
        executable: executable,
        arguments: List<String>.unmodifiable(arguments),
        environment: Map<String, String>.unmodifiable(environment ?? const {}),
        workingDirectory: workingDirectory,
        includeParentEnvironment: includeParentEnvironment,
      ),
    );
    if (p.basename(executable) != p.basename(serverPath)) return _HelperProcess();
    final agent = _AgentProcess(
      initialize: initialize,
      respondToInitialize: respondToInitialize,
      pid: agents.length + 10,
    );
    agents.add(agent);
    return agent;
  }

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    agents.singleWhere((agent) => agent.pid == pid).process.kill();
    return _signal(pid: pid, signal: ShutdownSignal.graceful);
  }

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    agents.singleWhere((agent) => agent.pid == pid).process.kill(ProcessSignal.sigkill);
    return _signal(pid: pid, signal: ShutdownSignal.force);
  }

  SignalResult _signal({required int pid, required ShutdownSignal signal}) => SignalResult(
    pid: pid,
    requestedSignal: signal,
    deliveredSignal: signal == ShutdownSignal.force ? ProcessSignal.sigkill : ProcessSignal.sigterm,
    wasRequested: true,
    attemptedAt: DateTime.now(),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Host({
  @override required final PluginConfig config,
  @override required final String stateDirectory,
  @override required final Map<String, String> environment,
  @override required final HostProcessService processes,
  @override required final HostJsonStore store,
  @override required final StartAbortSignal startAborted,
}) implements PluginHost {
  @override
  String? provisionedRuntimePath;
  @override
  ServerClock get clock => const ServerClock();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Http() implements HttpClient {
  @override
  String Function(Uri)? findProxy;
  bool closed = false;
  @override
  void close({bool force = false}) => closed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _initialize() =>
    jsonDecode(File("test/fixtures/official_initialize_1_0_0.json").readAsStringSync()) as Map<String, dynamic>;

({String server, String harness}) _writePair({required Directory directory}) {
  final server = p.join(directory.path, AntigravityRelease.serverFileName(target: _target));
  final harness = p.join(directory.path, AntigravityRelease.harnessFileName(target: _target));
  File(server).writeAsStringSync("synthetic server identity");
  File(harness).writeAsStringSync("synthetic harness identity");
  return (server: server, harness: harness);
}

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Directory state;
  late Directory runtime;
  late ({String server, String harness}) pair;
  late _Processes processes;
  late _Store store;

  setUp(() {
    state = Directory(Directory.systemTemp.createTempSync("antigravity-descriptor-state-").resolveSymbolicLinksSync());
    runtime = Directory(
      Directory.systemTemp.createTempSync("antigravity-descriptor-runtime-").resolveSymbolicLinksSync(),
    );
    pair = _writePair(directory: runtime);
    processes = _Processes(serverPath: pair.server, initialize: _initialize(), respondToInitialize: true);
    store = _Store(parent: null);
  });

  tearDown(() async {
    for (final agent in processes.agents) {
      await agent.process.close();
    }
    state.deleteSync(recursive: true);
    runtime.deleteSync(recursive: true);
  });

  HttpClient unexpectedHttpClient() => throw StateError("Authentication HTTP client was not expected");

  AntigravityPluginDescriptor descriptorWithTimeout({required _Http? http, required Duration timeout}) =>
      AntigravityPluginDescriptor(
        target: _target,
        browserExecutable: "/synthetic/bridge",
        browserPrefixArguments: const [],
        launchDirectory: "/synthetic/worktree",
        callbackHttpClientFactory: http == null ? unexpectedHttpClient : () => http,
        operationTimeout: timeout,
        connectBudget: const Duration(seconds: 2),
      );

  AntigravityPluginDescriptor descriptor({required _Http? http}) =>
      descriptorWithTimeout(http: http, timeout: const Duration(seconds: 2));

  PluginConfig config({required String? server}) =>
      PluginConfig(values: {AntigravityPluginDescriptor.binOption: server});

  test("inspection is inert, explicit is authoritative, and token contents are not read", () async {
    final candidate = descriptor(http: null);
    final missing = await candidate.inspectSetup(
      config: config(server: p.join(state.path, AntigravityRelease.posixServerFileName)),
      processes: processes,
      environment: {"PATH": runtime.path},
      stateDirectory: state.path,
    );
    expect(missing, isA<PluginSetupRuntimeMissing>());
    expect(processes.launches, isEmpty);
    expect(state.listSync(), isEmpty);

    final noToken = await candidate.inspectSetup(
      config: config(server: pair.server),
      processes: processes,
      environment: {"GOOGLE_API_KEY": "ambient"},
      stateDirectory: state.path,
    );
    expect(noToken, isA<PluginSetupAuthenticationRequired>());
    final token = File(p.join(state.path, "profile", "antigravity-acp", "acp_token.json"));
    token.parent.createSync(recursive: true);
    token.writeAsStringSync("synthetic-not-json-token-content");
    expect(
      await candidate.inspectSetup(
        config: config(server: pair.server),
        processes: processes,
        environment: const {},
        stateDirectory: state.path,
      ),
      const PluginSetupReady(),
    );
    expect(token.readAsStringSync(), "synthetic-not-json-token-content");
    expect(processes.launches, isEmpty);
    expect(store.scopes, isEmpty);
  });

  test("macOS x64 reports unsupported setup without preparing or launching a runtime", () async {
    final candidate = AntigravityPluginDescriptor(
      target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64),
      callbackHttpClientFactory: unexpectedHttpClient,
    );
    for (final server in [null, pair.server]) {
      final status = await candidate.inspectSetup(
        config: config(server: server),
        processes: processes,
        environment: {"PATH": runtime.path},
        stateDirectory: state.path,
      );
      expect(
        status,
        const PluginSetupUnavailable(
          actionHint: "Google does not publish the Antigravity ACP runtime for this platform.",
        ),
      );
    }
    expect(processes.launches, isEmpty);
    expect(store.scopes, isEmpty);
    expect(state.listSync(), isEmpty);
  });

  test("PATH precedes managed pair and keeps an empty POSIX entry as current directory", () async {
    final oldCurrent = Directory.current;
    Directory.current = runtime;
    try {
      expect(
        await descriptor(http: null).inspectSetup(
          config: config(server: null),
          processes: processes,
          environment: const {"PATH": ":/definitely/missing"},
          stateDirectory: state.path,
        ),
        isA<PluginSetupAuthenticationRequired>(),
      );
    } finally {
      Directory.current = oldCurrent;
    }
    expect(processes.launches, isEmpty);
  });

  test("managed pair is the inert fallback after PATH", () async {
    final managedDirectory = Directory(
      p.join(state.path, AntigravityIdentity.pluginId, AntigravityRelease.agentVersion),
    )..createSync(recursive: true);
    _writePair(directory: managedDirectory);
    expect(
      await descriptor(http: null).inspectSetup(
        config: config(server: null),
        processes: processes,
        environment: const {"PATH": "/definitely/missing"},
        stateDirectory: state.path,
      ),
      isA<PluginSetupAuthenticationRequired>(),
    );
    expect(processes.launches, isEmpty);
  });

  test("prepare, probe and live process share the isolated environment and existing lifecycle owner", () async {
    final token = File(p.join(state.path, "profile", "antigravity-acp", "acp_token.json"));
    token.parent.createSync(recursive: true);
    token.writeAsStringSync("presence only");
    final candidate = descriptor(http: null);
    final host = _Host(
      config: config(server: pair.server),
      stateDirectory: state.path,
      environment: {"PATH": "/usr/bin:/bin", "GOOGLE_API_KEY": "ambient-secret"},
      processes: processes,
      store: store,
      startAborted: StartAbortSignal.never,
    );
    final progress = await candidate.ensureRuntime(host: host).toList();
    expect(progress.single, isA<ProvisionReady>());
    host.provisionedRuntimePath = (progress.single as ProvisionReady).binaryPath;
    final bridge = await candidate.start(host);
    addTearDown(() => bridge.shutdown(budget: null));

    expect(bridge.currentStatus, isA<PluginReady>());
    expect(bridge.api, isA<AntigravityPlugin>());
    expect(processes.agents, hasLength(3), reason: "ensure probe, start probe, then live process");
    expect(processes.launches.every((launch) => !launch.includeParentEnvironment), isTrue);
    for (final launch in processes.launches) {
      expect(launch.environment, isNot(contains("GOOGLE_API_KEY")));
    }
    final live = processes.launches.last;
    expect(live.executable, pair.server);
    expect(live.arguments, isEmpty);
    expect(live.workingDirectory, "/synthetic/worktree");
    expect(live.environment[AntigravityRelease.harnessPathEnvironmentKey], pair.harness);
    expect(live.environment["GEMINI_HOME"], p.join(state.path, "profile"));
    expect(store.writes["settings.json"], '{"auth":{"type":"oauth-personal"}}\n');

    processes.agents.last.process.exit(17);
    await _settle();
    final api = bridge.api as AntigravityPlugin;
    expect(api.client, isNull, reason: "The existing lifecycle exit watch resets the dead connection");
    expect(await api.ensureConnected(), isTrue);
    await _settle();
    expect(bridge.currentStatus, isA<PluginReady>());
    expect(processes.agents, hasLength(4));
    await bridge.shutdown(budget: null);
    expect(bridge.currentStatus, isA<PluginStopped>());
    expect(await Future.wait(processes.agents.map((agent) => agent.exitCode)), everyElement(anyOf(-15, 17)));
  });

  test("source browser invocation uses the running entrypoint without opening a browser", () async {
    final http = _Http();
    final candidate = AntigravityPluginDescriptor(
      target: _target,
      launchDirectory: "/synthetic/worktree",
      callbackHttpClientFactory: () => http,
      operationTimeout: const Duration(seconds: 2),
      connectBudget: const Duration(seconds: 2),
    );
    final operation = candidate.authenticate(
      config: config(server: pair.server),
      processes: processes,
      environment: const {"GOOGLE_API_KEY": "ambient"},
      stateDirectory: state.path,
      store: store,
      aborted: StartAbortSignal.never,
    );
    expect(await operation.events.toList(), [isA<PluginAuthenticationCompleted>()]);
    final expectedPrefix = Platform.packageConfig == null
        ? const <String>[]
        : ["--packages=${Uri.parse(Platform.packageConfig!).toFilePath()}", Platform.script.toFilePath()];
    expect(processes.launches.first.executable, Platform.resolvedExecutable);
    expect(processes.launches.first.arguments, [
      ...expectedPrefix,
      BrowserNoop.argument,
      AntigravityProfileService.browserPreflightUrl,
    ]);
    expect(http.closed, isTrue);
    expect(processes.launches.every((launch) => !launch.includeParentEnvironment), isTrue);
    expect(processes.launches.every((launch) => !launch.environment.containsKey("GOOGLE_API_KEY")), isTrue);
  });

  test("probe timeout is logged and settles provisioning as best-effort failure", () async {
    processes = _Processes(serverPath: pair.server, initialize: _initialize(), respondToInitialize: false);
    final host = _Host(
      config: config(server: pair.server),
      stateDirectory: state.path,
      environment: const {},
      processes: processes,
      store: store,
      startAborted: StartAbortSignal.never,
    );
    final logs = BufferingStdout();
    final previousLevel = Log.level;
    late List<RuntimeProvisionProgress> progress;
    try {
      Log.level = LogLevel.debug;
      await IOOverrides.runZoned(
        () async => progress = await descriptorWithTimeout(
          http: null,
          timeout: const Duration(milliseconds: 50),
        ).ensureRuntime(host: host).toList(),
        stderr: () => logs,
      );
    } finally {
      Log.level = previousLevel;
    }

    expect(progress.single, isA<ProvisionFailed>());
    expect(logs.text, contains("TimeoutException"));
    expect(
      logs.text,
      anyOf(contains("No matching process activity"), contains("Antigravity ACP initialize probe exceeded")),
    );
    expect(logs.text, anyOf(contains("ndjson_process_client.dart"), contains("antigravity_acp_api.dart")));
    expect(processes.agents, hasLength(1));
    expect(await processes.agents.single.exitCode, -15);
  });

  test("initial abort prevents preparation and runtime launch", () async {
    final abort = StartAbortController()..abort();
    final host = _Host(
      config: config(server: pair.server),
      stateDirectory: state.path,
      environment: const {},
      processes: processes,
      store: store,
      startAborted: abort.signal,
    );
    await expectLater(
      descriptor(http: null).ensureRuntime(host: host).toList(),
      throwsA(isA<PluginStartAbortedException>()),
    );
    expect(processes.launches, isEmpty);
    expect(store.scopes, isEmpty);
  });

  test("authentication is browser-only, uses the supplied root store, and aborted attempts clean up", () async {
    final http = _Http();
    final abort = StartAbortController()..abort();
    final candidate = descriptor(http: http);
    expect(
      candidate.managementCapabilities(config: config(server: pair.server)),
      allOf(
        contains(PluginControlCapability.authentication),
        isNot(contains(PluginControlCapability.install)),
      ),
    );
    final operation = candidate.authenticate(
      config: config(server: pair.server),
      processes: processes,
      environment: const {"GOOGLE_API_KEY": "ambient"},
      stateDirectory: state.path,
      store: store,
      aborted: abort.signal,
    );
    expect(operation, isA<PluginAuthenticationBrowserOperation>());
    await expectLater(operation.events.toList(), throwsA(isA<PluginStartAbortedException>()));
    expect(http.closed, isTrue);
    expect(processes.launches, isEmpty);
    expect(store.scopes, ["profile", "antigravity-acp"]);
  });
}
