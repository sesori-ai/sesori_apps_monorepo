import "dart:async";
import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/debug_server.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_runtime.dart";
import "package:sesori_bridge/src/server/api/system_process_api.dart";
import "package:sesori_bridge/src/server/foundation/bridge_restart_command_builder.dart";
import "package:sesori_bridge/src/server/foundation/bridge_restart_env.dart";
import "package:sesori_bridge/src/server/repositories/process_repository.dart";
import "package:sesori_bridge/src/server/services/bridge_restart_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/restart_test_support.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";

_DebugServerHarness _createDebugServerHarness({
  required BridgePluginApi plugin,
  required AppDatabase db,
  required int port,
  required FailureReporter failureReporter,
  BridgeRestartService? restartService,
}) {
  final httpClient = http.Client();
  final runtime = BridgeRuntime.create(
    config: const BridgeConfig(
      relayURL: "ws://127.0.0.1:9999",
      pluginEndpoint: "http://127.0.0.1:4096",
      authBackendURL: "https://api.sesori.test",
      sseReplayWindow: Duration(minutes: 5),
      yolo: false,
    ),
    plugin: plugin,
    relayClient: RelayClient(
      relayURL: "ws://127.0.0.1:9999",
      accessTokenProvider: FakeAccessTokenProvider(),
      bridgeIdProvider: FakeBridgeIdProvider(),
    ),
    httpClient: httpClient,
    accessTokenProvider: FakeAccessTokenProvider(),
    tokenRefresher: _FakeTokenRefresher(),
    bridgeRegistrationService: createFakeBridgeRegistrationService(),
    database: db,
    processRunner: ProcessRunner(),
    failureReporter: failureReporter,
    restartService: restartService ?? buildTestRestartService(),
    filesystemAccessOk: true,
    statusNotifier: null,
  );
  final debugServer = runtime.createDebugServer(port: port);
  return _DebugServerHarness(
    runtime: runtime,
    debugServer: debugServer,
    httpClient: httpClient,
  );
}

void main() {
  group("DebugServer SSE multi-client", () {
    late _FakeBridgePlugin plugin;
    late AppDatabase db;
    late _DebugServerHarness harness;
    late DebugServer debugServer;

    setUp(() async {
      plugin = _FakeBridgePlugin();
      db = createTestDatabase();
      harness = _createDebugServerHarness(
        plugin: plugin,
        db: db,
        port: 0,
        failureReporter: FakeFailureReporter(),
      );
      debugServer = harness.debugServer;
      await debugServer.start();
    });

    tearDown(() async {
      await harness.close();
      await plugin.close();
    });

    test("second SSE client receives events alongside first", () async {
      final first = await _SseTestClient.connect(debugServer.boundPort!);
      addTearDown(first.close);

      final second = await _SseTestClient.connect(debugServer.boundPort!);
      addTearDown(second.close);

      plugin.add(const BridgeSseServerConnected());

      final firstEvent = await first.nextEvent();
      final secondEvent = await second.nextEvent();

      expect(firstEvent, contains("server.connected"));
      expect(secondEvent, contains("server.connected"));
    });

    test(
      "first client still receives events after second disconnects",
      () async {
        final first = await _SseTestClient.connect(debugServer.boundPort!);
        addTearDown(first.close);

        final second = await _SseTestClient.connect(debugServer.boundPort!);

        await second.close();

        plugin.add(const BridgeSseServerConnected());
        final firstEvent = await first.nextEvent();
        expect(firstEvent, contains("server.connected"));
      },
    );

    test("async-mapped session events preserve order for SSE clients", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "s1",
        projectId: "p1",
        isDedicated: true,
        createdAt: 10,
        worktreePath: "/tmp/worktree",
        branchName: "feature/one",
        baseBranch: null,
        baseCommit: null,

        lastAgent: null,
        lastAgentModel: null,
      );
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "p1",
          branchName: "feature/one",
          prNumber: 11,
          url: "https://github.com/org/repo/pull/11",
          title: "Newest open PR",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.mergeable,
          reviewDecision: PrReviewDecision.approved,
          checkStatus: PrCheckStatus.success,
          lastCheckedAt: 2,
          createdAt: 2,
        ),
      );

      final client = await _SseTestClient.connect(debugServer.boundPort!);
      addTearDown(client.close);

      plugin.add(
        const BridgeSseSessionCreated(
          info: {
            "id": "s1",
            "projectID": "p1",
            "directory": "/tmp/project",
            "parentID": null,
            "title": "session",
            "time": {"created": 1, "updated": 2, "archived": null},
            "summary": null,
          },
        ),
      );
      plugin.add(const BridgeSseSessionDiff(sessionID: "s1"));

      final firstEvent = jsonDecode(await client.nextEvent()) as Map<String, dynamic>;
      final secondEvent = jsonDecode(await client.nextEvent()) as Map<String, dynamic>;

      expect(firstEvent["type"], equals("session.created"));
      expect(secondEvent["type"], equals("session.diff"));
      expect(
        ((firstEvent["info"] as Map<String, dynamic>)["pullRequest"] as Map<String, dynamic>)["number"],
        equals(11),
      );
    });

    test("plugin subscription is released when last client disconnects", () async {
      final trackingPlugin = _TrackingBridgePlugin();
      final trackingDb = createTestDatabase();
      final trackingHarness = _createDebugServerHarness(
        plugin: trackingPlugin,
        db: trackingDb,
        port: 0,
        failureReporter: FakeFailureReporter(),
      );
      final trackingServer = trackingHarness.debugServer;
      await trackingServer.start();
      addTearDown(trackingHarness.close);
      addTearDown(trackingPlugin.close);

      final first = await _SseTestClient.connect(trackingServer.boundPort!);
      final second = await _SseTestClient.connect(trackingServer.boundPort!);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(trackingPlugin.subscribeCount, equals(1));

      await second.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(trackingPlugin.unsubscribeCount, equals(0));

      await first.close();
      await trackingServer.stop();
      expect(trackingPlugin.unsubscribeCount, equals(1));
    });

    test("a failed projects summary is reported and later events still flow", () async {
      final failureReporter = CapturingFailureReporter();
      final failingPlugin = _FakeBridgePlugin()..throwOnActiveSummary = true;
      final failingDb = createTestDatabase();
      final failingHarness = _createDebugServerHarness(
        plugin: failingPlugin,
        db: failingDb,
        port: 0,
        failureReporter: failureReporter,
      );
      final failingServer = failingHarness.debugServer;
      await failingServer.start();
      addTearDown(failingHarness.close);
      addTearDown(failingPlugin.close);

      final client = await _SseTestClient.connect(failingServer.boundPort!);
      addTearDown(client.close);
      failingPlugin.add(const BridgeSseProjectUpdated());
      failingPlugin.add(const BridgeSseServerConnected());

      expect(await client.nextEvent(), contains("server.connected"));
      final timeoutAt = DateTime.now().add(const Duration(seconds: 2));
      while (!failureReporter.recordedIdentifiers.contains("bridge.debug_server.projects_summary")) {
        if (DateTime.now().isAfter(timeoutAt)) {
          fail("Timed out waiting for projects-summary failure reporting");
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
  });

  group("DebugServer HTTP requests", () {
    late _FakeBridgePlugin plugin;
    late AppDatabase db;
    late _DebugServerHarness harness;
    late DebugServer debugServer;

    setUp(() async {
      plugin = _FakeBridgePlugin();
      db = createTestDatabase();
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/tmp/test"]);
      harness = _createDebugServerHarness(
        plugin: plugin,
        db: db,
        port: 0,
        failureReporter: FakeFailureReporter(),
      );
      debugServer = harness.debugServer;
      await debugServer.start();
    });

    tearDown(() async {
      await harness.close();
      await plugin.close();
    });

    test("GET /projects returns project list as JSON", () async {
      plugin.projectsResult = [
        const PluginProject(id: "p1", directory: "p1", name: "My Project"),
      ];

      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.getUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/projects"),
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      expect(response.statusCode, equals(HttpStatus.ok));
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final data = decoded["data"] as List<dynamic>;
      expect(data.length, equals(1));
      final project = data[0] as Map<String, dynamic>;
      expect(project["id"], equals("p1"));
      expect(project["name"], equals("My Project"));
    });

    test("POST /sessions without body returns 400", () async {
      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.postUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/sessions"),
      );
      final response = await request.close();
      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test("POST /sessions with body returns session list", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp/test",
          parentID: null,
          title: null,
          time: null,
        ),
      ];

      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.postUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/sessions"),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({"projectId": "/tmp/test", "start": null, "limit": null}));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      expect(response.statusCode, equals(HttpStatus.ok));
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final items = decoded["items"] as List<dynamic>;
      expect(items.length, equals(1));
      final session = items[0] as Map<String, dynamic>;
      expect(session["id"], equals("s1"));
    });

    test("POST /session/messages returns messages", () async {
      plugin.messagesResult = [
        const PluginMessageWithParts(
          info: PluginMessage.user(
            id: "m1",
            sessionID: "s1",
            agent: null,
            time: null,
          ),
          parts: [],
        ),
      ];

      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.postUrl(
        Uri.parse(
          "http://127.0.0.1:${debugServer.boundPort!}/session/messages",
        ),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({"sessionId": "s1"}));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      expect(response.statusCode, equals(HttpStatus.ok));
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final messages = decoded["messages"] as List<dynamic>;
      expect(messages.length, equals(1));
    });

    test("returns 500 on plugin error", () async {
      plugin.throwOnGetProjects = true;

      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.getUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/projects"),
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      expect(response.statusCode, equals(HttpStatus.internalServerError));
      expect(body, contains("Internal Server Error"));
    });
  });

  group("DebugServer restart", () {
    test("POST /global/restart replies and spawns a successor", () async {
      final plugin = _FakeBridgePlugin();
      addTearDown(plugin.close);
      final db = createTestDatabase();

      final tempDir = await Directory.systemTemp.createTemp("debug-server-restart");
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final binaryPath = p.join(tempDir.path, "sesori-bridge");
      File(binaryPath).writeAsStringSync("binary");
      if (!Platform.isWindows) {
        await Process.run("chmod", ["+x", binaryPath]);
      }

      final processRunner = _RecordingProcessRunner();
      final harness = _createDebugServerHarness(
        plugin: plugin,
        db: db,
        port: 0,
        failureReporter: FakeFailureReporter(),
        restartService: _spawnableRestartService(
          binaryPath: binaryPath,
          processRunner: processRunner,
        ),
      );
      addTearDown(harness.close);
      final debugServer = harness.debugServer;
      await debugServer.start();

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.postUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/global/restart"),
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(body, contains('"restarting":true'));
      // The handoff actually ran: a successor was spawned with the predecessor
      // pid in the environment (the phone-restart contract).
      expect(processRunner.startDetachedCount, equals(1));
      expect(
        processRunner.lastEnvironment?[sesoriRestartPredecessorPidEnvVar],
        equals("4321"),
      );
    });

    test("concurrent restart handoffs spawn at most one successor", () async {
      final plugin = _FakeBridgePlugin();
      addTearDown(plugin.close);
      final db = createTestDatabase();

      final tempDir = await Directory.systemTemp.createTemp("debug-server-restart-single");
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final binaryPath = p.join(tempDir.path, "sesori-bridge");
      File(binaryPath).writeAsStringSync("binary");
      if (!Platform.isWindows) {
        await Process.run("chmod", ["+x", binaryPath]);
      }

      final processRunner = _RecordingProcessRunner();
      final harness = _createDebugServerHarness(
        plugin: plugin,
        db: db,
        port: 0,
        failureReporter: FakeFailureReporter(),
        restartService: _spawnableRestartService(
          binaryPath: binaryPath,
          processRunner: processRunner,
        ),
      );
      addTearDown(harness.close);

      // Both the relay and debug triggers funnel into handleRestartHandoff;
      // fire two concurrently and assert the single-flight guard holds.
      await Future.wait<void>([
        harness.runtime.session.handleRestartHandoff(),
        harness.runtime.session.handleRestartHandoff(),
      ]);

      expect(processRunner.startDetachedCount, equals(1));
    });

    test("POST /global/restart returns 503 and does not spawn when binary is missing", () async {
      final plugin = _FakeBridgePlugin();
      addTearDown(plugin.close);
      final db = createTestDatabase();

      final tempDir = await Directory.systemTemp.createTemp("debug-server-restart-missing");
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final processRunner = _RecordingProcessRunner();
      final harness = _createDebugServerHarness(
        plugin: plugin,
        db: db,
        port: 0,
        failureReporter: FakeFailureReporter(),
        restartService: _spawnableRestartService(
          binaryPath: p.join(tempDir.path, "missing"),
          processRunner: processRunner,
        ),
      );
      addTearDown(harness.close);
      final debugServer = harness.debugServer;
      await debugServer.start();

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.postUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/global/restart"),
      );
      final response = await request.close();

      expect(response.statusCode, equals(HttpStatus.serviceUnavailable));
      expect(processRunner.startDetachedCount, equals(0));
    });
  });
}

BridgeRestartService _spawnableRestartService({
  required String binaryPath,
  required ProcessRunner processRunner,
}) {
  return BridgeRestartService(
    processRepository: ProcessRepository(
      api: SystemProcessApi(
        processRunner: processRunner,
        clock: const ServerClock(),
        isWindows: false,
        platform: "linux",
      ),
      currentUser: null,
    ),
    commandBuilder: const BridgeRestartCommandBuilder(),
    binaryPath: binaryPath,
    cliArgs: const <String>[],
    currentPid: 4321,
    isSupervised: false,
  );
}

/// Records `startDetached` calls so the restart handoff can be asserted; `run`
/// is never expected during these tests.
class _RecordingProcessRunner implements ProcessRunner {
  int startDetachedCount = 0;
  String? lastExecutable;
  List<String>? lastArguments;
  Map<String, String>? lastEnvironment;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    startDetachedCount++;
    lastExecutable = executable;
    lastArguments = arguments;
    lastEnvironment = environment;
    return 4242;
  }
}

class _DebugServerHarness {
  final BridgeRuntime runtime;
  final DebugServer debugServer;
  final http.Client httpClient;

  const _DebugServerHarness({
    required this.runtime,
    required this.debugServer,
    required this.httpClient,
  });

  Future<void> close() async {
    await debugServer.stop();
    await runtime.close();
    httpClient.close();
  }
}

class _FakeTokenRefresher implements TokenRefresher {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async => "test-token";
}

// ---------------------------------------------------------------------------
// Fake plugin implementations
// ---------------------------------------------------------------------------

class _FakeBridgePlugin implements NativeProjectsPluginApi {
  final _controller = StreamController<BridgeSseEvent>.broadcast();

  List<PluginProject> projectsResult = [];
  List<PluginSession> sessionsResult = [];
  List<PluginMessageWithParts> messagesResult = [];
  bool throwOnGetProjects = false;
  bool throwOnActiveSummary = false;

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => _controller.stream;

  @override
  Future<List<PluginProject>> getProjects() async {
    if (throwOnGetProjects) throw Exception("fake error");
    return projectsResult;
  }

  @override
  Future<List<PluginSession>> getSessions(
    String worktree, {
    int? start,
    int? limit,
  }) async => sessionsResult;

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
  );

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
  );

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) async =>
      const PluginProject(id: "", directory: "");

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<void> archiveSession({required String sessionId}) async {}

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {}

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => [];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => {};

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId,
  ) async => messagesResult;

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async => [];

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async => [];

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {}

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {}

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {}

  @override
  Future<PluginProject> getProject(String projectId) async => const PluginProject(id: "", directory: "");

  @override
  Future<bool> healthCheck() async => true;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    if (throwOnActiveSummary) throw StateError("summary failed");
    return [];
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async =>
      const PluginProvidersResult(providers: []);

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async => [];

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<void> dispose() async {}

  void add(BridgeSseEvent event) => _controller.add(event);
  Future<void> close() => _controller.close();
}

/// Plugin that tracks subscribe/unsubscribe counts via a wrapping stream.
class _TrackingBridgePlugin implements NativeProjectsPluginApi {
  final _eventController = StreamController<BridgeSseEvent>.broadcast();
  int subscribeCount = 0;
  int unsubscribeCount = 0;

  @override
  String get id => "tracking";

  @override
  Stream<BridgeSseEvent> get events {
    return Stream<BridgeSseEvent>.multi((controller) {
      subscribeCount++;
      final sub = _eventController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () {
        unsubscribeCount++;
        sub.cancel();
      };
    });
  }

  @override
  Future<List<PluginProject>> getProjects() async => [];

  @override
  Future<List<PluginSession>> getSessions(
    String worktree, {
    int? start,
    int? limit,
  }) async => [];

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
  );

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
  );

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) async =>
      const PluginProject(id: "", directory: "");

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<void> archiveSession({required String sessionId}) async {}

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {}

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => [];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => {};

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId,
  ) async => [];

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async => [];

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async => [];

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {}

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {}

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {}

  @override
  Future<PluginProject> getProject(String projectId) async => const PluginProject(id: "", directory: "");

  @override
  Future<bool> healthCheck() async => true;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => [];

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async => [];

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async =>
      const PluginProvidersResult(providers: []);

  @override
  Future<void> dispose() async {}

  Future<void> close() => _eventController.close();
}

// ---------------------------------------------------------------------------
// SSE test client
// ---------------------------------------------------------------------------

class _SseTestClient {
  final Socket _socket;
  final StreamIterator<String> _lines;

  _SseTestClient._(this._socket, this._lines);

  static Future<_SseTestClient> connect(int port) async {
    final socket = await Socket.connect("127.0.0.1", port);
    socket.write(
      "GET /global/event HTTP/1.0\r\n"
      "Host: 127.0.0.1\r\n"
      "Accept: text/event-stream\r\n"
      "\r\n",
    );

    final lineController = StreamController<String>();
    final lines = StreamIterator(lineController.stream);

    var buffer = "";
    var headersParsed = false;
    var lineBuffer = "";

    socket.listen(
      (chunk) {
        buffer += utf8.decode(chunk);

        if (!headersParsed) {
          final headerEnd = buffer.indexOf("\r\n\r\n");
          if (headerEnd == -1) {
            return;
          }
          headersParsed = true;
          buffer = buffer.substring(headerEnd + 4);
        }

        lineBuffer += buffer;
        buffer = "";

        final parts = lineBuffer.split("\n");
        lineBuffer = parts.removeLast();
        for (final part in parts) {
          final line = part.endsWith("\r") ? part.substring(0, part.length - 1) : part;
          lineController.add(line);
        }
      },
      onDone: () {
        if (!lineController.isClosed) {
          lineController.close();
        }
      },
      onError: (_) {
        if (!lineController.isClosed) {
          lineController.close();
        }
      },
      cancelOnError: true,
    );

    final instance = _SseTestClient._(socket, lines);
    await instance._waitForReady();
    return instance;
  }

  Future<String> nextEvent() async {
    while (await _lines.moveNext()) {
      final line = _lines.current;
      if (line.startsWith("data: ")) {
        return line.substring(6);
      }
    }
    throw StateError("SSE stream ended before event arrived");
  }

  Future<void> close() async {
    await _socket.close();
    await _lines.cancel();
  }

  Future<void> _waitForReady() async {
    while (await _lines.moveNext()) {
      if (_lines.current == ": ok") {
        return;
      }
    }
    throw StateError("SSE stream ended before ready marker");
  }
}
