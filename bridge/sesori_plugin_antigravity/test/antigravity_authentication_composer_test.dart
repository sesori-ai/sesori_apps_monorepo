import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_testing.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class _Store() implements HostJsonStore {
  final scopes = <String>[];
  String? settings;
  @override
  HostJsonStore scope({required String directoryName}) {
    scopes.add(directoryName);
    return this;
  }

  @override
  Future<void> write({required String name, required String contents}) async {
    expect(name, "settings.json");
    settings = contents;
  }

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

class _Input({required final FakeAcpProcess process, required final Map<String, dynamic> initialize})
    extends CapturingIOSink {
  @override
  void add(List<int> data) {
    super.add(data);
    final request = frames.last;
    switch (request["method"]) {
      case "initialize":
        process.emit({"id": request["id"], "result": initialize});
      case "authenticate":
        expect(request["params"], {"methodId": "oauth-personal"});
        process.emit({"id": request["id"], "result": <String, dynamic>{}});
      default:
        fail("Authentication must not create sessions or dispatch prompts");
    }
  }
}

class _Agent({required final Map<String, dynamic> initialize, @override required final int pid})
    implements SpawnedProcess {
  final process = FakeAcpProcess();
  @override
  late final stdin = _Input(process: process, initialize: initialize);
  @override
  Stream<List<int>> get stdout => process.stdout;
  @override
  Stream<List<int>> get stderr => process.stderr;
  @override
  Future<int> get exitCode => process.exitCode;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Helper() implements SpawnedProcess {
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

class _Processes({required final Map<String, dynamic> initialize}) implements HostProcessService {
  final agents = <_Agent>[];
  final launches = <({String command, List<String> arguments, Map<String, String> environment})>[];
  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) async {
    expect(includeParentEnvironment, isFalse);
    expect(environment, isNotNull);
    expect(environment, isNot(contains("GOOGLE_API_KEY")));
    launches.add((command: executable, arguments: arguments, environment: environment!));
    if (executable == "/synthetic/bridge" || executable == "chmod") return _Helper();
    final agent = _Agent(initialize: initialize, pid: agents.length + 10);
    agents.add(agent);
    return agent;
  }

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    agents.singleWhere((agent) => agent.pid == pid).process.kill();
    return SignalResult(
      pid: pid,
      requestedSignal: ShutdownSignal.graceful,
      deliveredSignal: ProcessSignal.sigterm,
      wasRequested: true,
      attemptedAt: DateTime.now(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test("composition uses shared profile scopes and isolated helpers/probe/auth", () async {
    final directory = Directory(
      Directory.systemTemp.createTempSync("antigravity-composition-").resolveSymbolicLinksSync(),
    );
    const target = PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64);
    final serverPath = p.join(directory.path, AntigravityRelease.serverFileName(target: target));
    File(serverPath).writeAsStringSync("synthetic runtime identity only");
    File(p.join(directory.path, AntigravityRelease.harnessFileName(target: target)))
        .writeAsStringSync("synthetic sibling");
    final fixture =
        jsonDecode(File("test/fixtures/official_initialize_1_0_0.json").readAsStringSync()) as Map<String, dynamic>;
    final processes = _Processes(initialize: fixture);
    final store = _Store();
    final http = _Http();
    try {
      final operation = const AntigravityAuthenticationComposer().compose(
        processes: processes,
        store: store,
        callbackHttpClient: http,
        stateDirectory: directory.path,
        environment: {"GOOGLE_API_KEY": "synthetic-ambient-secret", "PATH": "/usr/bin:/bin"},
        target: target,
        browserExecutable: "/synthetic/bridge",
        browserPrefixArguments: [],
        explicitServerPath: serverPath,
        managedServerPath: null,
        aborted: StartAbortSignal.never,
        timeout: const Duration(seconds: 2),
      );
      expect(store.scopes, ["profile", "antigravity-acp"]);
      expect(processes.launches, isEmpty);
      expect(Directory(p.join(directory.path, "profile")).existsSync(), isFalse);
      final events = await operation.events.toList();
      expect(events, [isA<PluginAuthenticationCompleted>()]);
      expect(store.settings, '{"auth":{"type":"oauth-personal"}}\n');
      expect(processes.launches.map((launch) => launch.command), [
        "/synthetic/bridge",
        "chmod",
        "chmod",
        serverPath,
        serverPath,
      ]);
      expect(processes.launches.first.arguments, [BrowserNoop.argument, AntigravityProfileService.browserPreflightUrl]);
      final preflightEnvironment = processes.launches.first.environment;
      for (final launch in processes.launches.skip(3)) {
        expect(launch.environment, {
          ...preflightEnvironment,
          AntigravityRelease.harnessPathEnvironmentKey: p.join(directory.path, "localharness_external"),
        });
      }
      expect(processes.agents, hasLength(2));
      for (final agent in processes.agents) {
        expect(await agent.exitCode, -15);
      }
      expect(http.closed, isTrue);
    } finally {
      for (final agent in processes.agents) {
        await agent.process.close();
      }
      directory.deleteSync(recursive: true);
    }
  });
}
