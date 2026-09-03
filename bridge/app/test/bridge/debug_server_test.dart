import "dart:async";
import "dart:convert";
import "dart:io";

import "package:cryptography/cryptography.dart";
import "package:http/http.dart" as http;
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/debug_server.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/relay_client.dart";
import "package:sesori_bridge/src/models/bridge_config.dart";
import "package:sesori_bridge/src/orchestrator.dart";
import "package:sesori_bridge/src/repositories/bridge_settings.dart";
import "package:sesori_bridge/src/routing/bridge_restart_dispatcher.dart";
import "package:sesori_bridge/src/routing/request_router.dart";
import "package:sesori_bridge/src/routing/restart_bridge_handler.dart";
import "package:sesori_bridge/src/routing/routed_request.dart";
import "package:sesori_bridge/src/routing/routed_request_dispatcher.dart";
import "package:sesori_bridge/src/runtime/bridge_runtime.dart";
import "package:sesori_bridge/src/runtime/bridge_shutdown_coordinator.dart";
import "package:sesori_bridge/src/server/api/system_process_api.dart";
import "package:sesori_bridge/src/server/foundation/bridge_restart_command_builder.dart";
import "package:sesori_bridge/src/server/foundation/bridge_restart_env.dart";
import "package:sesori_bridge/src/server/repositories/process_repository.dart";
import "package:sesori_bridge/src/server/services/bridge_restart_service.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
import "../helpers/restart_test_support.dart";
import "../helpers/test_chat_history.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";

Future<_DebugServerHarness> _createDebugServerHarness({
  required BridgePluginApi plugin,
  required AppDatabase db,
  required int port,
  required FailureReporter failureReporter,
  BridgeRestartService? restartService,
}) async {
  final httpClient = http.Client();
  final relayServer = await TestRelayServer.start();
  final relayUrl = "ws://127.0.0.1:${relayServer.port}";
  final lifecycleService = await createSinglePluginLifecycleService(plugin: plugin);
  final effectiveRestartService = restartService ?? buildTestRestartService();
  final testChatHistory = createTestChatHistory();
  final composition = Orchestrator(
    config: BridgeConfig(
      relayURL: relayUrl,
      authBackendURL: "https://api.sesori.test",
      sseReplayWindow: const Duration(minutes: 5),
      yolo: false,
    ),
    client: RelayClient(
      relayURL: relayUrl,
      accessTokenProvider: FakeAccessTokenProvider(),
      bridgeIdProvider: FakeBridgeIdProvider(),
    ),
    pluginLifecycleService: lifecycleService,
    pluginRuntime: runtimeForLifecycleService(service: lifecycleService),
    bridgeSettingsRepository: settingsRepositoryForLifecycleService(service: lifecycleService),
    clock: const ServerClock(),
    database: db,
    chatHistoryDatabase: testChatHistory.database,
    attachmentSpillStorage: testChatHistory.spillStorage,
    archivedSessionStorage: testChatHistory.archivedStorage,
    httpClient: httpClient,
    processRunner: ProcessRunner(),
    accessTokenProvider: FakeAccessTokenProvider(),
    tokenRefresher: FakeTokenRefresher(),
    bridgeRegistrationService: createFakeBridgeRegistrationService(),
    failureReporter: failureReporter,
    restartService: effectiveRestartService,
    filesystemAccessOk: true,
    statusNotifier: null,
    reconnectBackoff: ReconnectBackoffPolicy.standard,
  ).create();
  final runtime = BridgeRuntime(
    database: db,
    chatHistoryDatabase: testChatHistory.database,
    failureReporter: failureReporter,
    composition: composition,
  );
  final running = await startTestOrchestratorSession(session: composition.session);
  final runFuture = running.stopped;
  final bridgeSocket = await relayServer.nextClient();
  await activateTestPlugin(service: lifecycleService, pluginId: plugin.id);
  if (plugin case final _SubscriptionAwarePlugin subscriptionAware) {
    await subscriptionAware.eventsSubscribed.timeout(const Duration(seconds: 2));
  }
  final debugServer = runtime.createDebugServer(port: port);
  return _DebugServerHarness(
    runtime: runtime,
    debugServer: debugServer,
    httpClient: httpClient,
    lifecycleService: lifecycleService,
    relayServer: relayServer,
    bridgeSocket: bridgeSocket,
    runFuture: runFuture,
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
      harness = await _createDebugServerHarness(
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

      plugin.add(const BridgeSseVcsBranchUpdated());

      final firstEvent = await first.nextEvent();
      final secondEvent = await second.nextEvent();

      expect(firstEvent, contains("vcs.branch.updated"));
      expect(secondEvent, contains("vcs.branch.updated"));
    });

    test("UTF-8 event data remains readable and the connection stays open", () async {
      final client = await _SseTestClient.connect(debugServer.boundPort!);
      addTearDown(client.close);

      plugin.add(const BridgeSseWorkspaceReady(name: "developer’s workspace"));

      final unicodeEvent = jsonDecodeMap(await client.nextEvent());
      expect(unicodeEvent["type"], "workspace.ready");
      expect(unicodeEvent["name"], "developer’s workspace");

      plugin.add(const BridgeSseVcsBranchUpdated());

      final followingEvent = jsonDecodeMap(await client.nextEvent());
      expect(followingEvent["type"], "vcs.branch.updated");
    });

    test(
      "first client still receives events after second disconnects",
      () async {
        final first = await _SseTestClient.connect(debugServer.boundPort!);
        addTearDown(first.close);

        final second = await _SseTestClient.connect(debugServer.boundPort!);

        await second.close();

        plugin.add(const BridgeSseVcsBranchUpdated());
        final firstEvent = await first.nextEvent();
        expect(firstEvent, contains("vcs.branch.updated"));
      },
    );

    test("async-mapped session events preserve order for SSE clients", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        preservePullRequestScope: false,
        sessionId: "s1",
        backendSessionId: "s1",
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
      await db.projectsDao.setPrCacheGithubLogin(
        projectId: "p1",
        githubLogin: "octocat",
      );
      await db.sessionDao.updatePullRequestScopes(
        updates: [
          (
            sessionId: "s1",
            currentBranchName: "feature/one",
            currentGithubRepositoryIdentity: "org/repo",
          ),
        ],
      );
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "p1",
          githubRepositoryIdentity: "org/repo",
          githubLogin: "octocat",
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

      final mappedEvents = <Map<String, dynamic>>[];
      while (mappedEvents.length < 2) {
        final event = jsonDecode(await client.nextEvent()) as Map<String, dynamic>;
        if (event["type"] == "session.created" || event["type"] == "session.diff") {
          mappedEvents.add(event);
        }
      }
      final firstEvent = mappedEvents.first;
      final secondEvent = mappedEvents.last;

      expect(firstEvent["type"], equals("session.created"));
      expect(secondEvent["type"], equals("session.diff"));
      expect((firstEvent["info"] as Map<String, dynamic>)["pullRequest"], isNull);
    });

    test("debug client disconnect does not tear down the orchestrator plugin listeners", () async {
      final trackingPlugin = _TrackingBridgePlugin();
      final trackingDb = createTestDatabase();
      final trackingHarness = await _createDebugServerHarness(
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
      expect(trackingPlugin.subscribeCount, equals(2));

      await second.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(trackingPlugin.unsubscribeCount, equals(0));

      await first.close();
      await trackingServer.drain();
      expect(trackingPlugin.unsubscribeCount, equals(0));
    });

    test("a failed projects summary is isolated and later events still flow", () async {
      final failingPlugin = _FakeBridgePlugin()..throwOnActiveSummary = true;
      final failingDb = createTestDatabase();
      final failingHarness = await _createDebugServerHarness(
        plugin: failingPlugin,
        db: failingDb,
        port: 0,
        failureReporter: FakeFailureReporter(),
      );
      final failingServer = failingHarness.debugServer;
      await failingServer.start();
      addTearDown(failingHarness.close);
      addTearDown(failingPlugin.close);

      final client = await _SseTestClient.connect(failingServer.boundPort!);
      addTearDown(client.close);
      failingPlugin.add(const BridgeSseProjectUpdated());
      failingPlugin.add(const BridgeSseVcsBranchUpdated());

      String event;
      do {
        event = await client.nextEvent();
      } while (!event.contains("vcs.branch.updated"));
      expect(event, contains("vcs.branch.updated"));
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
      harness = await _createDebugServerHarness(
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
      await db.projectsDao.setDisplayName(
        projectId: "/tmp/test",
        displayName: "My Project",
        updatedAt: 1,
      );

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
      expect(project["id"], equals("/tmp/test"));
      expect(project["name"], equals("My Project"));
    });

    test("GET /plugin/management uses the shared session router", () async {
      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.getUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/plugin/management"),
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;

      expect(response.statusCode, HttpStatus.ok);
      expect(decoded["defaultPluginId"], "fake");
      expect(decoded["defaultIdleTimeoutMins"], defaultPluginIdleTimeoutMins);
      final plugins = decoded["plugins"] as List<dynamic>;
      final plugin = plugins.single as Map<String, dynamic>;
      expect((plugin["setup"] as Map<String, dynamic>)["id"], "fake");
      expect(plugin["runtimeState"], "active");
      expect(plugin["idleTimeoutMins"], defaultPluginIdleTimeoutMins);
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
      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        preservePullRequestScope: false,
        sessionId: "stable-s1",
        backendSessionId: "s1",
        projectId: "/tmp/test",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );

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
      final sessionId = session["id"] as String;
      expect(sessionId, "stable-s1");
      final binding = await db.sessionDao.getSession(sessionId: sessionId);
      expect(binding?.backendSessionId, "s1");
    });

    test("POST /session/messages returns messages", () async {
      plugin.messagesResult = [
        const PluginMessageWithParts(
          info: PluginMessage.user(
            promptId: null,
            id: "m1",
            sessionID: "s1",
            agent: null,
            time: null,
          ),
          parts: [],
        ),
      ];
      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        preservePullRequestScope: false,
        sessionId: "s1",
        backendSessionId: "backend-s1",
        projectId: "/tmp/test",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );

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
      expect(plugin.messageSessionIds, equals(["backend-s1"]));
    });

    test("catalog project browsing remains available on plugin error", () async {
      plugin.throwOnGetProjects = true;

      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.getUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/projects"),
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(body, contains("/tmp/test"));
    });
  });

  group("DebugServer shutdown", () {
    test("session and debug drains share one relay and debug route barrier", () async {
      final db = createTestDatabase();
      final plugin = _BlockingRoutesPlugin();
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/tmp/test"]);
      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        preservePullRequestScope: false,
        sessionId: "s1",
        backendSessionId: "backend-s1",
        projectId: "/tmp/test",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );
      final harness = await _createDebugServerHarness(
        plugin: plugin,
        db: db,
        port: 0,
        failureReporter: FakeFailureReporter(),
      );
      addTearDown(plugin.close);
      addTearDown(harness.close);
      addTearDown(() {
        plugin
          ..releaseAbort()
          ..releaseMessages();
      });
      final debugServer = harness.debugServer;
      await debugServer.start();
      final phone = await _activatePhone(harness: harness, connId: 7);

      await _sendEncryptedRelayMessage(
        socket: harness.bridgeSocket,
        connId: 7,
        encryptor: phone.encryptor,
        message: RelayMessage.request(
          id: "relay-route",
          method: "POST",
          path: "/session/messages",
          headers: const {"content-type": "application/json"},
          body: jsonEncode(const SessionIdRequest(sessionId: "s1").toJson()),
        ),
      );
      await plugin.messagesStarted.timeout(const Duration(seconds: 2));

      final client = HttpClient();
      addTearDown(client.close);
      final abortRequest = await client.postUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/session/abort"),
      );
      abortRequest.headers.contentType = ContentType.json;
      abortRequest.write(jsonEncode(const SessionIdRequest(sessionId: "s1").toJson()));
      final abortResponseFuture = abortRequest.close();
      await plugin.abortStarted.timeout(const Duration(seconds: 2));

      var sessionStopped = false;
      unawaited(harness.runFuture.whenComplete(() => sessionStopped = true));
      await harness.runtime.session.cancel();

      final rejectedRequest = await client.getUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/global/health"),
      );
      final rejectedResponse = await rejectedRequest.close();
      expect(rejectedResponse.statusCode, HttpStatus.serviceUnavailable);
      expect(await utf8.decoder.bind(rejectedResponse).join(), "bridge is shutting down");
      await Future<void>.delayed(Duration.zero);
      expect(sessionStopped, isFalse);

      plugin.releaseAbort();
      final abortResponse = await abortResponseFuture.timeout(const Duration(seconds: 2));
      await utf8.decoder.bind(abortResponse).join().timeout(const Duration(seconds: 2));
      expect(abortResponse.statusCode, HttpStatus.ok);

      debugServer.beginShutdown();
      var debugDrained = false;
      final debugDrain = debugServer.drain().whenComplete(() => debugDrained = true);
      await Future<void>.delayed(Duration.zero);
      expect(sessionStopped, isFalse);
      expect(debugDrained, isFalse);

      plugin.releaseMessages();
      await Future.wait([
        harness.runFuture.timeout(const Duration(seconds: 2)),
        debugDrain.timeout(const Duration(seconds: 2)),
      ]);
      expect(sessionStopped, isTrue);
      expect(debugDrained, isTrue);
    });

    test("drains and persists a routed mutation before plugin teardown", () async {
      final db = createTestDatabase();
      String? persistedTitleAtDispose;
      final plugin = _BlockingMutationPlugin(
        onDispose: () async {
          persistedTitleAtDispose = (await db.sessionDao.getSession(sessionId: "s1"))?.title;
        },
      );
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/tmp/test"]);
      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        preservePullRequestScope: false,
        sessionId: "s1",
        backendSessionId: "backend-s1",
        projectId: "/tmp/test",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );
      final harness = await _createDebugServerHarness(
        plugin: plugin,
        db: db,
        port: 0,
        failureReporter: FakeFailureReporter(),
      );
      addTearDown(plugin.close);
      addTearDown(harness.close);
      addTearDown(plugin.releaseMutation);
      final debugServer = harness.debugServer;
      final shutdownCoordinator =
          BridgeShutdownCoordinator(
              startAbortSignal: StartAbortSignal.never,
              exitProcess: (_) {},
            )
            ..addPhase(
              phase: BridgeShutdownPhase.signal,
              action: harness.runtime.session.beginShutdown,
            )
            ..addPhase(
              phase: BridgeShutdownPhase.signal,
              action: debugServer.beginShutdown,
            )
            ..addPhase(
              phase: BridgeShutdownPhase.drain,
              action: () => harness.runFuture,
            )
            ..addPhase(
              phase: BridgeShutdownPhase.drain,
              action: debugServer.drain,
            )
            ..addPhase(
              phase: BridgeShutdownPhase.pluginDispose,
              action: plugin.dispose,
            );
      await debugServer.start();

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.patchUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/session/title"),
      );
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(const RenameSessionRequest(sessionId: "s1", title: "Renamed").toJson()),
      );
      final responseFuture = request.close();
      await plugin.mutationStarted.timeout(const Duration(seconds: 2));

      final shutdown = shutdownCoordinator.shutdown();
      final response = await responseFuture.timeout(const Duration(seconds: 2));
      await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 2));

      await Future<void>.delayed(Duration.zero);
      expect(plugin.disposeCalls, 0);
      expect(persistedTitleAtDispose, isNull);

      plugin.releaseMutation();
      await shutdown.timeout(const Duration(seconds: 2));
      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, "Renamed");
      expect(persistedTitleAtDispose, "Renamed");
      expect(plugin.disposeCalls, 1);
    });
  });

  group("DebugServer restart", () {
    test("closes the HTTP response before awaiting restart dispatch and drains the dispatch", () async {
      final dispatcher = _BlockingRestartDispatcher();
      final debugServer = DebugServer(
        localWireEvents: const Stream<SesoriSseEvent>.empty(),
        routedRequestDispatcher: RoutedRequestDispatcher(
          router: RequestRouter(
            handlers: [RestartBridgeHandler(restartService: _AlwaysRestartableService())],
          ),
        ),
        port: 0,
        failureReporter: FakeFailureReporter(),
        restartDispatcher: dispatcher,
      );
      await debugServer.start();
      addTearDown(() async {
        dispatcher.release();
        await debugServer.drain();
      });

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.postUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/global/restart"),
      );
      final responseFuture = request.close();

      await dispatcher.started.timeout(const Duration(seconds: 2));
      final response = await responseFuture.timeout(const Duration(seconds: 2));
      final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 2));
      expect(response.statusCode, HttpStatus.ok);
      expect(body, contains('"restarting":true'));

      var stopped = false;
      final stop = debugServer.drain().whenComplete(() => stopped = true);
      await Future<void>.delayed(Duration.zero);
      expect(stopped, isFalse);
      dispatcher.release();
      await stop.timeout(const Duration(seconds: 2));
    });

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
      final harness = await _createDebugServerHarness(
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
      final harness = await _createDebugServerHarness(
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

      Future<int> restart() async {
        final request = await client.postUrl(
          Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/global/restart"),
        );
        final response = await request.close();
        await utf8.decoder.bind(response).join();
        return response.statusCode;
      }

      final statuses = await Future.wait([restart(), restart()]);

      expect(statuses, contains(HttpStatus.ok));
      expect(statuses, everyElement(anyOf(HttpStatus.ok, HttpStatus.serviceUnavailable)));
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
      final harness = await _createDebugServerHarness(
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

Future<({StreamIterator<dynamic> messages, SessionEncryptor encryptor})> _activatePhone({
  required _DebugServerHarness harness,
  required int connId,
}) async {
  final messages = StreamIterator<dynamic>(harness.bridgeSocket);
  expect(await messages.moveNext(), isTrue);
  expect(jsonDecodeMap(messages.current as String)["type"], "auth");

  final crypto = RelayCryptoService();
  final phoneKeyPair = await crypto.generateKeyPair();
  final phonePublicKey = await phoneKeyPair.extractPublicKey();
  harness.bridgeSocket.add(<int>[
    0,
    connId,
    ...utf8.encode(
      jsonEncode(
        RelayMessage.keyExchange(
          publicKey: base64Url.encode(phonePublicKey.bytes).replaceAll("=", ""),
        ).toJson(),
      ),
    ),
  ]);

  expect(await messages.moveNext(), isTrue);
  final readyFrame = messages.current as List<int>;
  expect(readyFrame.sublist(0, 2), [0, connId]);
  final ready = await _decryptReady(
    response: readyFrame.sublist(2),
    phoneKeyPair: phoneKeyPair,
  );
  final roomKey = SecretKey(base64Url.decode(base64Url.normalize(ready.roomKey)));
  await harness.runtime.session.firstPhoneConnected.timeout(const Duration(seconds: 2));
  return (messages: messages, encryptor: crypto.createSessionEncryptor(roomKey));
}

Future<RelayReady> _decryptReady({
  required List<int> response,
  required SimpleKeyPair phoneKeyPair,
}) async {
  final crypto = RelayCryptoService();
  final bridgePublicKey = SimplePublicKey(response.sublist(0, 32), type: KeyPairType.x25519);
  final secret = await crypto.deriveSharedSecret(phoneKeyPair, peerPublicKey: bridgePublicKey);
  final encryptor = crypto.createSessionEncryptor(await crypto.deriveEncryptionKey(secret));
  final decrypted = await unframe(response.sublist(32), encryptor: encryptor);
  return RelayMessage.fromJson(jsonDecodeMap(utf8.decode(decrypted))) as RelayReady;
}

Future<void> _sendEncryptedRelayMessage({
  required WebSocket socket,
  required int connId,
  required SessionEncryptor encryptor,
  required RelayMessage message,
}) async {
  final payload = await frame(
    utf8.encode(jsonEncode(message.toJson())),
    encryptor: encryptor,
  );
  socket.add(<int>[0, connId, ...payload]);
}

class _BlockingRestartDispatcher() implements BridgeRestartDispatcher {
  final Completer<void> _started = Completer<void>();
  final Completer<void> _release = Completer<void>();

  Future<void> get started => _started.future;

  @override
  Stream<BridgeShutdownRequest> get shutdownRequests => const Stream<BridgeShutdownRequest>.empty();

  @override
  Future<void> dispatch({required RestartAccepted restart}) async {
    if (!_started.isCompleted) _started.complete();
    await _release.future;
  }

  void release() {
    if (!_release.isCompleted) _release.complete();
  }

  @override
  Future<void> dispose() async {}
}

class _AlwaysRestartableService() implements BridgeRestartService {
  @override
  Future<bool> canRestart() async => true;

  @override
  Future<bool> canSpawnSuccessor() async => true;

  @override
  Future<bool> performRestartHandoff() async => true;

  @override
  Future<bool> spawnSuccessor() async => true;
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
    onSupervisedRestartRequested: () {},
  );
}

/// Records `startDetached` calls so the restart handoff can be asserted; `run`
/// is never expected during these tests.
class _RecordingProcessRunner() implements ProcessRunner {
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

class const _DebugServerHarness({
  required final BridgeRuntime runtime,
  required final DebugServer debugServer,
  required final http.Client httpClient,
  required final PluginLifecycleService lifecycleService,
  required final TestRelayServer relayServer,
  required final WebSocket bridgeSocket,
  required final Future<void> runFuture,
}) {
  Future<void> close() async {
    await debugServer.drain();
    await runtime.session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await runtime.close();
    await lifecycleService.dispose();
    httpClient.close();
    await relayServer.close();
  }
}

// ---------------------------------------------------------------------------
// Fake plugin implementations
// ---------------------------------------------------------------------------

abstract interface class _SubscriptionAwarePlugin() {
  Future<void> get eventsSubscribed;
}

class _FakeBridgePlugin() implements NativeProjectsPluginApi, _SubscriptionAwarePlugin {
  @override
  Future<List<PluginQueuedPrompt>> getQueuedPrompts({required String sessionId}) async => const [];

  @override
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) async => false;

  final _controller = StreamController<BridgeSseEvent>.broadcast();
  final Completer<void> _eventsSubscribed = Completer<void>();

  List<PluginProject> projectsResult = [];
  List<PluginSession> sessionsResult = [];
  List<PluginMessageWithParts> messagesResult = [];
  List<String> messageSessionIds = [];
  bool throwOnGetProjects = false;
  bool throwOnActiveSummary = false;

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events {
    if (!_eventsSubscribed.isCompleted) _eventsSubscribed.complete();
    return _controller.stream;
  }

  @override
  Future<void> get eventsSubscribed => _eventsSubscribed.future;

  @override
  Future<List<PluginProject>> getProjects() async {
    if (throwOnGetProjects) throw Exception("fake error");
    return projectsResult;
  }

  @override
  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async => sessionsResult;

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
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
  ) async {
    messageSessionIds.add(sessionId);
    return messagesResult;
  }

  @override
  Future<void> sendPrompt({
    required String promptId,
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<PluginAbortResult> abortSession({
    required String sessionId,
    required PluginAbortSubAgentPolicy subAgents,
  }) async => const PluginAbortAccepted(workKept: false);

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
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  Future<void> sendCommand({
    required String promptId,
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  Future<void> dispose() async {}

  void add(BridgeSseEvent event) => _controller.add(event);
  Future<void> close() => _controller.close();
}

class _BlockingMutationPlugin({required final Future<void> Function() onDispose}) extends _FakeBridgePlugin {
  final Completer<void> _mutationStarted = Completer<void>();
  final Completer<void> _mutationRelease = Completer<void>();
  int disposeCalls = 0;

  Future<void> get mutationStarted => _mutationStarted.future;

  void releaseMutation() {
    if (!_mutationRelease.isCompleted) _mutationRelease.complete();
  }

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    _mutationStarted.complete();
    await _mutationRelease.future;
    return PluginSession(
      id: sessionId,
      projectID: "/tmp/test",
      directory: "/tmp/test",
      parentID: null,
      title: title,
      time: null,
    );
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await onDispose();
  }
}

class _BlockingRoutesPlugin() extends _FakeBridgePlugin {
  final Completer<void> _messagesStarted = Completer<void>();
  final Completer<void> _messagesRelease = Completer<void>();
  final Completer<void> _abortStarted = Completer<void>();
  final Completer<void> _abortRelease = Completer<void>();

  Future<void> get messagesStarted => _messagesStarted.future;
  Future<void> get abortStarted => _abortStarted.future;

  void releaseMessages() {
    if (!_messagesRelease.isCompleted) _messagesRelease.complete();
  }

  void releaseAbort() {
    if (!_abortRelease.isCompleted) _abortRelease.complete();
  }

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    _messagesStarted.complete();
    await _messagesRelease.future;
    return [];
  }

  @override
  Future<PluginAbortResult> abortSession({
    required String sessionId,
    required PluginAbortSubAgentPolicy subAgents,
  }) async {
    _abortStarted.complete();
    await _abortRelease.future;
    return const PluginAbortAccepted(workKept: false);
  }
}

/// Plugin that tracks subscribe/unsubscribe counts via a wrapping stream.
class _TrackingBridgePlugin() implements NativeProjectsPluginApi, _SubscriptionAwarePlugin {
  @override
  Future<List<PluginQueuedPrompt>> getQueuedPrompts({required String sessionId}) async => const [];

  @override
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) async => false;

  final _eventController = StreamController<BridgeSseEvent>.broadcast();
  final Completer<void> _eventsSubscribed = Completer<void>();
  int subscribeCount = 0;
  int unsubscribeCount = 0;

  @override
  String get id => "tracking";

  @override
  Stream<BridgeSseEvent> get events {
    return Stream<BridgeSseEvent>.multi((controller) {
      subscribeCount++;
      if (!_eventsSubscribed.isCompleted) _eventsSubscribed.complete();
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
  Future<void> get eventsSubscribed => _eventsSubscribed.future;

  @override
  Future<List<PluginProject>> getProjects() async => [];

  @override
  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async => [];

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
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
    required String promptId,
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<PluginAbortResult> abortSession({
    required String sessionId,
    required PluginAbortSubAgentPolicy subAgents,
  }) async => const PluginAbortAccepted(workKept: false);

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
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  Future<void> sendCommand({
    required String promptId,
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async =>
      const PluginProvidersResult(providers: []);

  Future<void> dispose() async {}

  Future<void> close() => _eventController.close();
}

// ---------------------------------------------------------------------------
// SSE test client
// ---------------------------------------------------------------------------

class _SseTestClient._(final Socket _socket, final StreamIterator<String> _lines) {
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

    utf8.decoder
        .bind(socket)
        .listen(
          (chunk) {
            buffer += chunk;

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
