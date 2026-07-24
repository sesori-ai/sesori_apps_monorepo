import "dart:async";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/orchestrator.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_runtime.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
import "../helpers/restart_test_support.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";
import "routing/routing_test_helpers.dart";

void main() {
  test("orchestrator composes plugin discovery from one ordered lifecycle view", () async {
    final harness = await _OrchestratorHarness.create(pluginIds: const ["one", "two"]);
    addTearDown(harness.close);

    final response = await harness.composition.session.router.route(makeRequest("GET", "/plugin"));
    final plugins = PluginListResponse.fromJson(jsonDecodeMap(response.body!)).plugins;

    expect(response.status, 200);
    expect(plugins.map((plugin) => plugin.id), ["one", "two"]);
    expect(plugins.map((plugin) => plugin.isDefault), [true, false]);
    expect(plugins.map((plugin) => plugin.state), everyElement(PluginLifecycleState.ready));
  });

  test("a sourced reconnect reconciles only its plugin and local events are already mapped", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one", "two"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });

    final runFuture = harness.composition.session.run();
    unawaited(runFuture.catchError((_) {}));
    await relayServer.nextClient();
    await _waitFor(
      () => harness.plugins.every((plugin) => plugin.getProjectsCallCount > 0),
      reason: "startup activity reconciliation",
    );
    final before = [for (final plugin in harness.plugins) plugin.getProjectsCallCount];

    harness.plugins.first.emitEvent(const BridgeSseServerConnected());
    await _waitFor(
      () => harness.plugins.first.getProjectsCallCount > before.first,
      reason: "source reconnect reconciliation",
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(harness.plugins.last.getProjectsCallCount, before.last);

    final localEvent = harness.composition.session.localWireEvents.firstWhere(
      (event) => event is SesoriVcsBranchUpdated,
    );
    harness.plugins.first.emitEvent(const BridgeSseVcsBranchUpdated());
    expect(await localEvent.timeout(const Duration(seconds: 2)), isA<SesoriVcsBranchUpdated>());

    await harness.composition.session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
  });

  test("post-normalization work is concurrent across plugins and ordered within each plugin", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one", "two"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });

    final runFuture = harness.composition.session.run();
    unawaited(runFuture.catchError((_) {}));
    await relayServer.nextClient();
    await _waitFor(
      () => harness.plugins.every((plugin) => plugin.getProjectsCallCount > 0),
      reason: "startup activity reconciliation",
    );

    final firstPlugin = harness.plugins.first;
    final projectReadStarted = Completer<void>();
    final projectReadGate = Completer<void>();
    firstPlugin
      ..getProjectsStarted = projectReadStarted
      ..getProjectsGate = projectReadGate;
    final branchEvents = <SesoriVcsBranchUpdated>[];
    final branchSubscription = harness.composition.session.localWireEvents
        .where((event) => event is SesoriVcsBranchUpdated)
        .cast<SesoriVcsBranchUpdated>()
        .listen(branchEvents.add);
    addTearDown(branchSubscription.cancel);

    firstPlugin.emitEvent(const BridgeSseServerConnected());
    await projectReadStarted.future.timeout(const Duration(seconds: 2));
    firstPlugin.emitEvent(const BridgeSseVcsBranchUpdated());
    harness.plugins.last.emitEvent(const BridgeSseVcsBranchUpdated());

    try {
      await _waitFor(
        () => branchEvents.isNotEmpty,
        reason: "second plugin event while first plugin is reconciling",
        timeout: const Duration(milliseconds: 500),
      );
      expect(
        branchEvents,
        hasLength(1),
        reason: "the following event from the first plugin must remain ordered behind reconciliation",
      );
    } finally {
      projectReadGate.complete();
    }

    await _waitFor(
      () => branchEvents.length == 2,
      reason: "first plugin event after reconciliation",
    );
    await harness.composition.session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
  });

  test("aggregate project summaries are built and delivered in trigger order across plugins", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one", "two"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });

    final runFuture = harness.composition.session.run();
    unawaited(runFuture.catchError((_) {}));
    await relayServer.nextClient();
    await _waitFor(
      () => harness.plugins.every((plugin) => plugin.getProjectsCallCount > 0),
      reason: "startup activity reconciliation",
    );
    final subscribed = harness.composition.session.localWireEvents.firstWhere(
      (event) => event is SesoriVcsBranchUpdated,
    );
    harness.plugins.last.emitEvent(const BridgeSseVcsBranchUpdated());
    await subscribed.timeout(const Duration(seconds: 2));

    const directory = "/projects/one";
    const oldSession = PluginSession(
      id: "old-session",
      projectID: directory,
      directory: directory,
      parentID: null,
      title: "Old session",
      time: PluginSessionTime(created: 1, updated: 1, archived: null),
    );
    const newSession = PluginSession(
      id: "new-session",
      projectID: directory,
      directory: directory,
      parentID: null,
      title: "New session",
      time: PluginSessionTime(created: 2, updated: 2, archived: null),
    );
    final firstPlugin = harness.plugins.first;
    final firstReadBlocked = Completer<void>();
    final releaseFirstRead = Completer<void>();
    firstPlugin
      ..activitySummaries = const [
        PluginProjectActivitySummary(
          id: directory,
          activeSessions: [PluginActiveSession(id: "old-session", awaitingInput: false)],
        ),
      ]
      ..currentProjectResult = const PluginProject(id: directory, directory: directory)
      ..sessionsResult = const [oldSession, newSession]
      ..getProjectStarted = firstReadBlocked
      ..getProjectGate = releaseFirstRead;
    final summaries = <SesoriProjectsSummary>[];
    final summarySubscription = harness.composition.session.localWireEvents
        .where((event) => event is SesoriProjectsSummary)
        .cast<SesoriProjectsSummary>()
        .listen(summaries.add);
    addTearDown(summarySubscription.cancel);

    firstPlugin.emitEvent(const BridgeSseProjectUpdated());
    await firstReadBlocked.future.timeout(const Duration(seconds: 2));

    final secondReadStarted = Completer<void>();
    firstPlugin
      ..activitySummaries = const [
        PluginProjectActivitySummary(
          id: directory,
          activeSessions: [PluginActiveSession(id: "new-session", awaitingInput: true)],
        ),
      ]
      ..activeSummaryReadStarted = secondReadStarted;
    harness.plugins.last.emitEvent(const BridgeSseProjectUpdated());

    var secondReadStartedWhileFirstWasBlocked = false;
    unawaited(
      secondReadStarted.future.then((_) {
        secondReadStartedWhileFirstWasBlocked = !releaseFirstRead.isCompleted;
        if (!releaseFirstRead.isCompleted) releaseFirstRead.complete();
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!releaseFirstRead.isCompleted) releaseFirstRead.complete();

    await _waitFor(() => summaries.length == 2, reason: "both project summaries");
    expect(secondReadStartedWhileFirstWasBlocked, isFalse);
    expect(
      summaries.map((summary) => summary.projects.single.activeSessions.single.awaitingInput),
      [false, true],
    );

    await harness.composition.session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
  });

  test("shutdown drains in-flight post-normalization work", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one", "two"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });

    final runFuture = harness.composition.session.run();
    unawaited(runFuture.catchError((_) {}));
    await relayServer.nextClient();
    await _waitFor(
      () => harness.plugins.every((plugin) => plugin.getProjectsCallCount > 0),
      reason: "startup activity reconciliation",
    );

    final projectReadStarted = Completer<void>();
    final projectReadGate = Completer<void>();
    harness.plugins.first
      ..getProjectsStarted = projectReadStarted
      ..getProjectsGate = projectReadGate;
    harness.plugins.first.emitEvent(const BridgeSseServerConnected());
    await projectReadStarted.future.timeout(const Duration(seconds: 2));

    var runCompleted = false;
    unawaited(runFuture.whenComplete(() => runCompleted = true));
    try {
      await harness.composition.session.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(runCompleted, isFalse);
    } finally {
      projectReadGate.complete();
    }
    await runFuture.timeout(const Duration(seconds: 5));
  });
}

Future<void> _waitFor(
  bool Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final timeoutAt = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(timeoutAt)) {
      fail("Timed out waiting for $reason");
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _OrchestratorHarness {
  final List<_SourcedPlugin> plugins;
  final PluginLifecycleService lifecycleService;
  final OrchestratorComposition composition;
  final BridgeRuntime runtime;
  final http.Client httpClient;

  const _OrchestratorHarness({
    required this.plugins,
    required this.lifecycleService,
    required this.composition,
    required this.runtime,
    required this.httpClient,
  });

  static Future<_OrchestratorHarness> create({
    required List<String> pluginIds,
    String relayUrl = "ws://127.0.0.1:1",
  }) async {
    final plugins = [for (final id in pluginIds) _SourcedPlugin(id)];
    final lifecycleService = await createPluginLifecycleService(plugins: plugins);
    final database = createTestDatabase();
    final httpClient = http.Client();
    final failureReporter = FakeFailureReporter();
    final restartService = buildTestRestartService();
    final composition = Orchestrator(
      config: BridgeConfig(
        relayURL: relayUrl,
        authBackendURL: "https://api.sesori.test",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: RelayClient(
        relayURL: relayUrl,
        accessTokenProvider: FakeAccessTokenProvider(),
        bridgeIdProvider: FakeBridgeIdProvider(),
      ),
      legacyMissingPluginId: "opencode",
      pluginLifecycleService: lifecycleService,
      pluginRuntime: runtimeForLifecycleService(service: lifecycleService),
      database: database,
      httpClient: httpClient,
      processRunner: ProcessRunner(),
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: _FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: failureReporter,
      restartService: restartService,
      filesystemAccessOk: true,
      statusNotifier: null,
    ).create();
    final runtime = BridgeRuntime(
      database: database,
      failureReporter: failureReporter,
      restartService: restartService,
      composition: composition,
    );
    return _OrchestratorHarness(
      plugins: plugins,
      lifecycleService: lifecycleService,
      composition: composition,
      runtime: runtime,
      httpClient: httpClient,
    );
  }

  Future<void> close() async {
    await composition.session.cancel();
    await runtime.close();
    await lifecycleService.dispose();
    httpClient.close();
    for (final plugin in plugins) {
      await plugin.closeEvents();
    }
  }
}

class _SourcedPlugin extends FakeBridgePlugin {
  _SourcedPlugin(this.pluginId);

  final String pluginId;
  Completer<void>? getProjectsStarted;
  Completer<void>? getProjectsGate;
  Completer<void>? getProjectStarted;
  Completer<void>? getProjectGate;
  Completer<void>? activeSummaryReadStarted;
  List<PluginProjectActivitySummary> activitySummaries = const [];

  @override
  String get id => pluginId;

  @override
  Future<List<PluginProject>> getProjects() async {
    getProjectsStarted?.complete();
    if (getProjectsGate case final gate?) await gate.future;
    return super.getProjects();
  }

  @override
  Future<PluginProject> getProject(String projectId) async {
    if (getProjectStarted case final started?) {
      getProjectStarted = null;
      final gate = getProjectGate;
      getProjectGate = null;
      started.complete();
      if (gate != null) await gate.future;
    }
    return super.getProject(projectId);
  }

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    activeSummaryReadStarted?.complete();
    activeSummaryReadStarted = null;
    return activitySummaries;
  }
}

class _FakeTokenRefresher implements TokenRefresher {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async => "token";
}
