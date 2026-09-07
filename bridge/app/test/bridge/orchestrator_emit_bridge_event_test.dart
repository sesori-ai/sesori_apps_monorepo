import "dart:async";
import "dart:convert";
import "dart:io";

import "package:cryptography/cryptography.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/foundation/relay_client.dart";
import "package:sesori_bridge/src/models/bridge_config.dart";
import "package:sesori_bridge/src/orchestrator.dart";
import "package:sesori_bridge/src/routing/routed_request_dispatcher.dart";
import "package:sesori_bridge/src/runtime/bridge_runtime.dart";
import "package:sesori_bridge/src/runtime/plugin_runtime.dart" as runtime show PluginRuntimeState;
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
import "../helpers/plugin_runtime_test_support.dart";
import "../helpers/restart_test_support.dart";
import "../helpers/test_chat_history.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";
import "routing/routing_test_helpers.dart";

void main() {
  test("orchestrator composes plugin discovery from one ordered lifecycle view", () async {
    final harness = await _OrchestratorHarness.create(pluginIds: const ["one", "two"]);
    addTearDown(harness.close);

    final response = await _dispatch(
      dispatcher: harness.composition.routedRequestDispatcher,
      request: makeRequest("GET", "/plugin"),
    );
    final plugins = PluginListResponse.fromJson(jsonDecodeMap(response.body!)).plugins;

    expect(response.status, 200);
    expect(plugins.map((plugin) => plugin.id), ["one", "two"]);
    expect(plugins.map((plugin) => plugin.isDefault), [true, false]);
    expect(plugins.map((plugin) => plugin.state), everyElement(PluginLifecycleState.ready));
  });

  test("orchestrator emits management invalidation after a runtime change", () async {
    final harness = await _OrchestratorHarness.create(pluginIds: const ["one"]);
    addTearDown(harness.close);
    final eventFuture = harness.composition.session.localWireEvents
        .where((event) => event is SesoriPluginManagementChanged)
        .cast<SesoriPluginManagementChanged>()
        .first;

    final pluginRuntime = runtimeForLifecycleService(service: harness.lifecycleService) as TestPluginRuntime;
    pluginRuntime.emitRuntimeState(pluginId: "one", state: runtime.PluginRuntimeState.degraded);

    final event = await eventFuture.timeout(const Duration(seconds: 2));
    expect(event.snapshotToken, hasLength(22));
    expect(harness.lifecycleService.managementSnapshot.snapshotToken, event.snapshotToken);
  });

  test("orchestrator routes live plugin idle timeout updates", () async {
    final harness = await _OrchestratorHarness.create(pluginIds: const ["one"]);
    addTearDown(harness.close);

    final response = await _dispatch(
      dispatcher: harness.composition.routedRequestDispatcher,
      request: makeRequest(
        "PATCH",
        "/plugin/idle-timeout",
        body: jsonEncode(
          const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "one", idleTimeoutMins: 25).toJson(),
        ),
      ),
    );
    final management = PluginManagementResponse.fromJson(jsonDecodeMap(response.body!));

    expect(response.status, 200);
    expect(management.plugins.single.idleTimeoutMins, 25);
    expect(management.plugins.single.hasIdleTimeoutOverride, isTrue);
  });

  test("orchestrator registers the plugin lifecycle command route", () async {
    final harness = await _OrchestratorHarness.create(pluginIds: const ["one"]);
    addTearDown(harness.close);

    final response = await _dispatch(
      dispatcher: harness.composition.routedRequestDispatcher,
      request: makeRequest(
        "POST",
        "/plugin/missing/command",
        body: jsonEncode(const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe).toJson()),
      ),
    );

    expect(response.status, 404);
    expect(response.body, "plugin not found");
  });

  test("the command route decodes install and maps a missing capability to a typed conflict", () async {
    final harness = await _OrchestratorHarness.create(pluginIds: const ["one"]);
    addTearDown(harness.close);

    final response = await _dispatch(
      dispatcher: harness.composition.routedRequestDispatcher,
      request: makeRequest(
        "POST",
        "/plugin/one/command",
        body: jsonEncode(const PluginLifecycleCommandRequest.install().toJson()),
      ),
    );

    expect(response.status, 409);
    final conflict = PluginLifecycleConflict.fromJson(jsonDecodeMap(response.body!));
    expect(conflict.reasons, [PluginLifecycleConflictReason.unsupported]);
  });

  test("orchestrator owns encrypted project-view claims across relay lifecycles", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });

    final running = await startTestOrchestratorSession(session: harness.composition.session);
    final runFuture = running.stopped;
    final firstSocket = await relayServer.nextClient();
    final firstMessages = StreamIterator<dynamic>(firstSocket);
    const firstConnection = 101;
    const secondConnection = 202;
    const firstProject = "test-project-x";
    const secondProject = "test-project-y";

    final roomKey = await _exchangeRoomKey(
      socket: firstSocket,
      messages: firstMessages,
      connID: firstConnection,
    );
    await _sendEncryptedRelayMessage(
      socket: firstSocket,
      connID: firstConnection,
      roomKey: roomKey,
      message: const RelayMessage.projectView(projectId: firstProject),
    );
    await _resumePhone(
      socket: firstSocket,
      messages: firstMessages,
      connID: secondConnection,
      roomKey: roomKey,
    );
    await _sendEncryptedRelayMessage(
      socket: firstSocket,
      connID: secondConnection,
      roomKey: roomKey,
      message: const RelayMessage.projectView(projectId: secondProject),
    );

    await _waitFor(
      () => harness.composition.projectViewTracker.activeProjectIds.length == 2,
      reason: "both project-view claims",
    );
    expect(harness.composition.projectViewTracker.activeProjectIds, {firstProject, secondProject});

    await _sendEncryptedRelayMessage(
      socket: firstSocket,
      connID: secondConnection,
      roomKey: roomKey,
      message: const RelayMessage.projectView(projectId: null),
    );
    await _waitFor(
      () => harness.composition.projectViewTracker.activeProjectIds.length == 1,
      reason: "null project-view declaration",
    );
    expect(harness.composition.projectViewTracker.activeProjectIds, {firstProject});

    await _sendEncryptedRelayMessage(
      socket: firstSocket,
      connID: secondConnection,
      roomKey: roomKey,
      message: const RelayMessage.projectView(projectId: secondProject),
    );
    await _waitFor(
      () => harness.composition.projectViewTracker.activeProjectIds.length == 2,
      reason: "project-view reassertion",
    );
    firstSocket.add(jsonEncode({"type": "phone_disconnected", "connId": firstConnection}));
    await _waitFor(
      () => harness.composition.projectViewTracker.activeProjectIds.length == 1,
      reason: "single phone disconnect",
    );
    expect(harness.composition.projectViewTracker.activeProjectIds, {secondProject});

    await firstSocket.close();
    await _waitFor(
      () => harness.composition.projectViewTracker.activeProjectIds.isEmpty,
      reason: "relay-drop project-view cleanup",
    );
    await firstMessages.cancel();

    final secondSocket = await relayServer.nextClient();
    final secondMessages = StreamIterator<dynamic>(secondSocket);
    const reconnectedConnection = 303;
    await _resumePhone(
      socket: secondSocket,
      messages: secondMessages,
      connID: reconnectedConnection,
      roomKey: roomKey,
    );
    await _sendEncryptedRelayMessage(
      socket: secondSocket,
      connID: reconnectedConnection,
      roomKey: roomKey,
      message: const RelayMessage.projectView(projectId: firstProject),
    );
    await _waitFor(
      () => harness.composition.projectViewTracker.activeProjectIds.isNotEmpty,
      reason: "reconnected project-view reassertion",
    );
    expect(harness.composition.projectViewTracker.activeProjectIds, {firstProject});

    secondSocket.add(jsonEncode({"type": "phone_disconnected", "connId": secondConnection}));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(harness.composition.projectViewTracker.activeProjectIds, {firstProject});

    await _sendEncryptedRelayMessage(
      socket: secondSocket,
      connID: reconnectedConnection,
      roomKey: roomKey,
      message: const RelayMessage.projectView(projectId: null),
    );
    await _waitFor(
      () => harness.composition.projectViewTracker.activeProjectIds.isEmpty,
      reason: "reconnected null declaration",
    );

    await harness.composition.session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await secondMessages.cancel();
  });

  test("committed user activity emits its durable marker in the unseen patch", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });
    final running = await startTestOrchestratorSession(session: harness.composition.session);
    final runFuture = running.stopped;
    await relayServer.nextClient();
    await harness.activatePlugins();
    await harness.database.projectsDao.insertProjectsIfMissing(projectIds: ["project"]);
    await harness.database.sessionDao.insertSession(
      sessionId: "session",
      backendSessionId: "session",
      projectId: "project",
      isDedicated: false,
      createdAt: 1,
      worktreePath: null,
      branchName: null,
      baseBranch: null,
      baseCommit: null,
      lastAgent: null,
      lastAgentModel: null,
      pluginId: "one",
      preservePullRequestScope: false,
    );
    final patch = harness.composition.session.localWireEvents
        .where((event) => event is SesoriSessionUnseenChanged)
        .cast<SesoriSessionUnseenChanged>()
        .first;

    harness.plugins.single.emitEvent(
      const BridgeSseMessageUpdated(
        info: PluginMessage.user(
          promptId: null,
          id: "message",
          sessionID: "session",
          agent: null,
          time: PluginMessageTime(created: 1234, completed: null),
        ),
      ),
    );

    final event = await patch.timeout(const Duration(seconds: 2));
    expect(event.sessionId, "session");
    expect(event.lastUserActivityAt, 1234);
    expect((await harness.database.sessionDao.getSession(sessionId: "session"))?.lastUserMessageAt, 1234);

    await harness.composition.session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
  });

  test("a sourced reconnect reconciles its active plugin and local events are already mapped", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one", "two"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });

    final running = await startTestOrchestratorSession(session: harness.composition.session);
    final runFuture = running.stopped;
    await relayServer.nextClient();
    await harness.activatePlugins();
    final before = [for (final plugin in harness.plugins) plugin.getProjectsCallCount];

    harness.plugins.first.emitEvent(const BridgeSseServerConnected());
    await _waitFor(
      () => harness.plugins.first.getProjectsCallCount > before.first,
      reason: "source reconnect reconciliation",
    );
    expect(harness.plugins.last.getProjectsCallCount, before.last);

    final localEvent = harness.composition.session.localWireEvents.firstWhere(
      (event) => event is SesoriVcsBranchUpdated,
    );
    harness.plugins.first.emitEvent(const BridgeSseVcsBranchUpdated());
    expect(await localEvent.timeout(const Duration(seconds: 2)), isA<SesoriVcsBranchUpdated>());

    await harness.composition.session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
  });

  test("a plugin wrapper cannot spoof the stop fence and runtime handoff is consumed after delivery", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });
    final running = await startTestOrchestratorSession(session: harness.composition.session);
    final runFuture = running.stopped;
    await relayServer.nextClient();
    await harness.activatePlugins();
    final pluginRuntime = runtimeForLifecycleService(service: harness.lifecycleService) as TestPluginRuntime;
    final events = <SesoriSseEvent>[];
    final subscription = harness.composition.session.localWireEvents.listen(events.add);
    addTearDown(subscription.cancel);
    pluginRuntime.generationCurrent = false;
    final terminalHandoffConsumed = Completer<void>();

    harness.plugins.single.emitEvent(const BridgeSseVcsBranchUpdated());
    harness.plugins.single.emitEvent(
      const BridgeSseTerminalHandoff(event: BridgeSseProjectUpdated()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(events.whereType<SesoriProjectsSummary>(), isEmpty);
    expect(events.whereType<SesoriVcsBranchUpdated>(), isEmpty);

    pluginRuntime.emitRuntimeEvent(
      pluginId: "one",
      event: const BridgeSseTerminalHandoff(event: BridgeSseProjectUpdated()),
      allowDuringStop: true,
      terminalHandoffConsumed: terminalHandoffConsumed,
    );

    await terminalHandoffConsumed.future.timeout(const Duration(seconds: 2));
    expect(events.whereType<SesoriProjectsSummary>(), hasLength(1));

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

    final running = await startTestOrchestratorSession(session: harness.composition.session);
    final runFuture = running.stopped;
    await relayServer.nextClient();
    await harness.activatePlugins();

    final firstPlugin = harness.plugins.first;
    final projectReadStarted = Completer<void>();
    final projectReadGate = Completer<void>();
    _configureBlockingProjectSummary(
      plugin: firstPlugin,
      started: projectReadStarted,
      gate: projectReadGate,
    );
    final branchEvents = <SesoriVcsBranchUpdated>[];
    final branchSubscription = harness.composition.session.localWireEvents
        .where((event) => event is SesoriVcsBranchUpdated)
        .cast<SesoriVcsBranchUpdated>()
        .listen(branchEvents.add);
    addTearDown(branchSubscription.cancel);

    firstPlugin.emitEvent(const BridgeSseProjectUpdated());
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

  test("session upserts emitted during backend deletion stay suppressed", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });
    final running = await startTestOrchestratorSession(session: harness.composition.session);
    final runFuture = running.stopped;
    await relayServer.nextClient();
    await harness.activatePlugins();
    await _insertEventSession(database: harness.database, pluginId: "one");
    final plugin = harness.plugins.single;
    final deletionStarted = Completer<void>();
    final deletionGate = Completer<void>();
    plugin
      ..deleteSessionStarted = deletionStarted
      ..deleteSessionGate = deletionGate;
    final updates = <SesoriSessionUpdated>[];
    final updateSubscription = harness.composition.session.localWireEvents
        .where((event) => event is SesoriSessionUpdated)
        .cast<SesoriSessionUpdated>()
        .listen(updates.add);
    final laterEventDelivered = harness.composition.session.localWireEvents
        .where((event) => event is SesoriVcsBranchUpdated)
        .first;
    final deletion = _deleteEventSession(
      dispatcher: harness.composition.routedRequestDispatcher,
    );

    try {
      await deletionStarted.future.timeout(const Duration(seconds: 2));
      plugin.emitEvent(_lateSessionUpdate(pluginId: plugin.id));
      plugin.emitEvent(const BridgeSseVcsBranchUpdated());
      await _waitForCatalogTitle(database: harness.database, title: "Late title");
      await laterEventDelivered.timeout(const Duration(seconds: 2));

      expect(updates, isEmpty);
    } finally {
      if (!deletionGate.isCompleted) deletionGate.complete();
      expect((await deletion).status, 200);
      await updateSubscription.cancel();
      await harness.composition.session.cancel();
      await runFuture.timeout(const Duration(seconds: 5));
    }
  });

  test("queued session upserts are rechecked after deletion", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });
    final running = await startTestOrchestratorSession(session: harness.composition.session);
    final runFuture = running.stopped;
    await relayServer.nextClient();
    await harness.activatePlugins();
    await _insertEventSession(database: harness.database, pluginId: "one");
    final plugin = harness.plugins.single;
    final projectReadStarted = Completer<void>();
    final projectReadGate = Completer<void>();
    _configureBlockingProjectSummary(
      plugin: plugin,
      started: projectReadStarted,
      gate: projectReadGate,
    );
    final updates = <SesoriSessionUpdated>[];
    final updateSubscription = harness.composition.session.localWireEvents
        .where((event) => event is SesoriSessionUpdated)
        .cast<SesoriSessionUpdated>()
        .listen(updates.add);
    final laterEventDelivered = harness.composition.session.localWireEvents
        .where((event) => event is SesoriVcsBranchUpdated)
        .first;

    try {
      plugin.emitEvent(const BridgeSseProjectUpdated());
      await projectReadStarted.future.timeout(const Duration(seconds: 2));
      plugin.emitEvent(_lateSessionUpdate(pluginId: plugin.id));
      plugin.emitEvent(const BridgeSseVcsBranchUpdated());
      await _waitForCatalogTitle(database: harness.database, title: "Late title");
      expect(
        (await _deleteEventSession(dispatcher: harness.composition.routedRequestDispatcher)).status,
        200,
      );

      projectReadGate.complete();
      await laterEventDelivered.timeout(const Duration(seconds: 2));

      expect(updates, isEmpty);
    } finally {
      if (!projectReadGate.isCompleted) projectReadGate.complete();
      await updateSubscription.cancel();
      await harness.composition.session.cancel();
      await runFuture.timeout(const Duration(seconds: 5));
    }
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

    final running = await startTestOrchestratorSession(session: harness.composition.session);
    final runFuture = running.stopped;
    await relayServer.nextClient();
    await harness.activatePlugins();
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

  test("initial SSE summary is detached and reserves summary delivery order", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });

    final running = await startTestOrchestratorSession(session: harness.composition.session);
    final runFuture = running.stopped;
    final socket = await relayServer.nextClient();
    final messages = StreamIterator<dynamic>(socket);
    final roomKey = await _exchangeRoomKey(
      socket: socket,
      messages: messages,
      connID: 404,
    );
    await harness.activatePlugins();

    const directory = "/projects/subscription-order";
    const oldSession = PluginSession(
      id: "initial-session",
      projectID: directory,
      directory: directory,
      parentID: null,
      title: "Initial session",
      time: PluginSessionTime(created: 1, updated: 1, archived: null),
    );
    const newSession = PluginSession(
      id: "later-session",
      projectID: directory,
      directory: directory,
      parentID: null,
      title: "Later session",
      time: PluginSessionTime(created: 2, updated: 2, archived: null),
    );
    final plugin = harness.plugins.single;
    final initialReadStarted = Completer<void>();
    final releaseInitialRead = Completer<void>();
    plugin
      ..activitySummaries = const [
        PluginProjectActivitySummary(
          id: directory,
          activeSessions: [PluginActiveSession(id: "initial-session", awaitingInput: false)],
        ),
      ]
      ..currentProjectResult = const PluginProject(id: directory, directory: directory)
      ..sessionsResult = const [oldSession, newSession]
      ..getProjectStarted = initialReadStarted
      ..getProjectGate = releaseInitialRead;
    final summaries = <SesoriProjectsSummary>[];
    final summarySubscription = harness.composition.session.localWireEvents
        .where((event) => event is SesoriProjectsSummary)
        .cast<SesoriProjectsSummary>()
        .listen(summaries.add);

    try {
      await _sendEncryptedRelayMessage(
        socket: socket,
        connID: 404,
        roomKey: roomKey,
        message: const RelayMessage.sseSubscribe(path: "/events"),
      );
      await initialReadStarted.future.timeout(const Duration(seconds: 2));

      final laterReadStarted = Completer<void>();
      plugin
        ..activitySummaries = const [
          PluginProjectActivitySummary(
            id: directory,
            activeSessions: [PluginActiveSession(id: "later-session", awaitingInput: true)],
          ),
        ]
        ..activeSummaryReadStarted = laterReadStarted;
      plugin.emitEvent(const BridgeSseProjectUpdated());
      await _sendEncryptedRelayMessage(
        socket: socket,
        connID: 404,
        roomKey: roomKey,
        message: const RelayMessage.projectView(projectId: "relay-remains-responsive"),
      );

      try {
        await _waitFor(
          () => harness.composition.projectViewTracker.activeProjectIds.contains("relay-remains-responsive"),
          reason: "relay control while initial summary is blocked",
          timeout: const Duration(milliseconds: 500),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(
          laterReadStarted.isCompleted,
          isFalse,
          reason: "the later summary must wait behind the already-enqueued initial build",
        );
      } finally {
        if (!releaseInitialRead.isCompleted) releaseInitialRead.complete();
      }

      await laterReadStarted.future.timeout(const Duration(seconds: 2));
      await _waitFor(() => summaries.length == 2, reason: "initial and later summaries");
      expect(
        summaries.map((summary) => summary.projects.single.activeSessions.single.awaitingInput),
        [false, true],
      );
    } finally {
      if (!releaseInitialRead.isCompleted) releaseInitialRead.complete();
      await summarySubscription.cancel();
      await harness.composition.session.cancel();
      await runFuture.timeout(const Duration(seconds: 5));
      await messages.cancel();
    }
  });

  test("shutdown drains a detached initial summary without broadcasting it late", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });

    final running = await startTestOrchestratorSession(session: harness.composition.session);
    final runFuture = running.stopped;
    final socket = await relayServer.nextClient();
    final messages = StreamIterator<dynamic>(socket);
    final roomKey = await _exchangeRoomKey(
      socket: socket,
      messages: messages,
      connID: 405,
    );
    await harness.activatePlugins();
    final summaryStarted = Completer<void>();
    final summaryGate = Completer<void>();
    _configureBlockingProjectSummary(
      plugin: harness.plugins.single,
      started: summaryStarted,
      gate: summaryGate,
    );
    final summaries = <SesoriProjectsSummary>[];
    final summarySubscription = harness.composition.session.localWireEvents
        .where((event) => event is SesoriProjectsSummary)
        .cast<SesoriProjectsSummary>()
        .listen(summaries.add);
    var stopped = false;
    runFuture.then((_) => stopped = true).ignore();

    try {
      await _sendEncryptedRelayMessage(
        socket: socket,
        connID: 405,
        roomKey: roomKey,
        message: const RelayMessage.sseSubscribe(path: "/events"),
      );
      await summaryStarted.future.timeout(const Duration(seconds: 2));

      await harness.composition.session.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(stopped, isFalse);

      summaryGate.complete();
      await runFuture.timeout(const Duration(seconds: 5));
      expect(summaries, isEmpty);
    } finally {
      if (!summaryGate.isCompleted) summaryGate.complete();
      await summarySubscription.cancel();
      await harness.composition.session.cancel();
      await runFuture.timeout(const Duration(seconds: 5));
      await messages.cancel();
    }
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

    final running = await startTestOrchestratorSession(session: harness.composition.session);
    final runFuture = running.stopped;
    await relayServer.nextClient();
    await harness.activatePlugins();

    final projectReadStarted = Completer<void>();
    final projectReadGate = Completer<void>();
    _configureBlockingProjectSummary(
      plugin: harness.plugins.first,
      started: projectReadStarted,
      gate: projectReadGate,
    );
    harness.plugins.first.emitEvent(const BridgeSseProjectUpdated());
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

Future<RelayResponse> _dispatch({
  required RoutedRequestDispatcher dispatcher,
  required RelayRequest request,
}) async {
  final result = dispatcher.dispatch(request: request);
  if (result case final RoutedRequestAccepted accepted) {
    return (await accepted.pendingRequest.completion).response;
  }
  throw StateError("route was rejected during test setup");
}

Future<RelayResponse> _deleteEventSession({required RoutedRequestDispatcher dispatcher}) {
  return _dispatch(
    dispatcher: dispatcher,
    request: makeRequest(
      "DELETE",
      "/session/delete",
      body: jsonEncode(
        const DeleteSessionRequest(
          sessionId: "stable-session",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ).toJson(),
      ),
    ),
  );
}

Future<void> _insertEventSession({required AppDatabase database, required String pluginId}) async {
  await database.projectsDao.insertProjectsIfMissing(projectIds: ["project"]);
  await database.sessionDao.insertSession(
    pluginId: pluginId,
    preservePullRequestScope: false,
    sessionId: "stable-session",
    backendSessionId: "backend-session",
    projectId: "project",
    isDedicated: false,
    createdAt: 1,
    worktreePath: null,
    branchName: null,
    baseBranch: null,
    baseCommit: null,
    lastAgent: null,
    lastAgentModel: null,
  );
}

BridgeSseSessionUpdated _lateSessionUpdate({required String pluginId}) {
  return BridgeSseSessionUpdated(
    info: Session(
      id: "backend-session",
      pluginId: pluginId,
      projectID: "project",
      directory: "/repo",
      parentID: null,
      title: "Late title",
      time: const SessionTime(created: 1, updated: 2, archived: null),
      pullRequest: null,
      promptDefaults: null,
      lastUserActivityAt: null,
      branchName: null,
    ).toJson(),
    titleChanged: true,
  );
}

Future<void> _waitForCatalogTitle({required AppDatabase database, required String title}) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 2));
  while ((await database.sessionDao.getSession(sessionId: "stable-session"))?.catalogTitle != title) {
    if (DateTime.now().isAfter(timeoutAt)) fail("Timed out waiting for the session projection");
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void _configureBlockingProjectSummary({
  required _SourcedPlugin plugin,
  required Completer<void> started,
  required Completer<void> gate,
}) {
  const directory = "/projects/blocked";
  plugin
    ..activitySummaries = const [
      PluginProjectActivitySummary(
        id: directory,
        activeSessions: [PluginActiveSession(id: "session", awaitingInput: false)],
      ),
    ]
    ..currentProjectResult = const PluginProject(id: directory, directory: directory)
    ..sessionsResult = const [
      PluginSession(
        id: "session",
        projectID: directory,
        directory: directory,
        parentID: null,
        title: "Session",
        time: PluginSessionTime(created: 1, updated: 1, archived: null),
      ),
    ]
    ..getProjectStarted = started
    ..getProjectGate = gate;
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

Future<List<int>> _exchangeRoomKey({
  required WebSocket socket,
  required StreamIterator<dynamic> messages,
  required int connID,
}) async {
  final crypto = RelayCryptoService();
  final phoneKeyPair = await crypto.generateKeyPair();
  final phonePublicKey = await phoneKeyPair.extractPublicKey();
  _sendRelayPayload(
    socket: socket,
    connID: connID,
    payload: utf8.encode(
      jsonEncode(
        RelayMessage.keyExchange(
          publicKey: base64Url.encode(phonePublicKey.bytes).replaceAll("=", ""),
        ).toJson(),
      ),
    ),
  );

  final response = await _nextRelayPayload(messages: messages, connID: connID);
  expect(response, hasLength(greaterThan(32)));
  final bridgePublicKey = SimplePublicKey(
    response.sublist(0, 32),
    type: KeyPairType.x25519,
  );
  final sharedSecret = await crypto.deriveSharedSecret(
    phoneKeyPair,
    peerPublicKey: bridgePublicKey,
  );
  final ephemeralKey = await crypto.deriveEncryptionKey(sharedSecret);
  final ready = await _decryptRelayMessage(
    payload: response.sublist(32),
    key: ephemeralKey,
  );
  expect(ready, isA<RelayReady>());
  return base64Url.decode(base64Url.normalize((ready as RelayReady).roomKey));
}

Future<void> _resumePhone({
  required WebSocket socket,
  required StreamIterator<dynamic> messages,
  required int connID,
  required List<int> roomKey,
}) async {
  await _sendEncryptedRelayMessage(
    socket: socket,
    connID: connID,
    roomKey: roomKey,
    message: const RelayMessage.resume(),
  );
  final response = await _nextRelayPayload(messages: messages, connID: connID);
  final acknowledgement = await _decryptRelayMessage(
    payload: response,
    key: SecretKey(List<int>.from(roomKey)),
  );
  expect(acknowledgement, isA<RelayResumeAck>());
}

Future<void> _sendEncryptedRelayMessage({
  required WebSocket socket,
  required int connID,
  required List<int> roomKey,
  required RelayMessage message,
}) async {
  final encryptor = RelayCryptoService().createSessionEncryptor(
    SecretKey(List<int>.from(roomKey)),
  );
  final payload = await frame(
    utf8.encode(jsonEncode(message.toJson())),
    encryptor: encryptor,
  );
  _sendRelayPayload(socket: socket, connID: connID, payload: payload);
}

Future<RelayMessage> _decryptRelayMessage({
  required List<int> payload,
  required SecretKey key,
}) async {
  final decryptor = RelayCryptoService().createSessionEncryptor(key);
  final decrypted = await unframe(payload, encryptor: decryptor);
  return RelayMessage.fromJson(jsonDecodeMap(utf8.decode(decrypted)));
}

void _sendRelayPayload({
  required WebSocket socket,
  required int connID,
  required List<int> payload,
}) {
  socket.add(<int>[connID >> 8, connID & 0xFF, ...payload]);
}

Future<List<int>> _nextRelayPayload({
  required StreamIterator<dynamic> messages,
  required int connID,
}) async {
  while (await messages.moveNext().timeout(const Duration(seconds: 5))) {
    final message = messages.current;
    if (message is! List<int> || message.length < 2) continue;
    final messageConnID = message[0] << 8 | message[1];
    if (messageConnID == connID) return message.sublist(2);
  }
  throw StateError("Relay socket closed before the expected bridge payload");
}

class const _OrchestratorHarness({
  required final List<_SourcedPlugin> plugins,
  required final PluginLifecycleService lifecycleService,
  required final OrchestratorComposition composition,
  required final BridgeRuntime runtime,
  required final AppDatabase database,
  required final http.Client httpClient,
}) {
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
    final testChatHistory = createTestChatHistory();
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
      pluginLifecycleRepository: lifecycleRepositoryForLifecycleService(service: lifecycleService),
      pluginLifecycleService: lifecycleService,
      pluginRuntime: runtimeForLifecycleService(service: lifecycleService),
      bridgeSettingsRepository: settingsRepositoryForLifecycleService(service: lifecycleService),
      clock: const ServerClock(),
      database: database,
      chatHistoryDatabase: testChatHistory.database,
      attachmentSpillStorage: testChatHistory.spillStorage,
      archivedSessionStorage: testChatHistory.archivedStorage,
      httpClient: httpClient,
      processRunner: NoopProcessRunner(),
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: FakeTokenRefresher(token: "token"),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: failureReporter,
      restartService: restartService,
      filesystemAccessOk: true,
      statusNotifier: null,
      reconnectBackoff: ReconnectBackoffPolicy.standard,
    ).create();
    final runtime = BridgeRuntime(
      database: database,
      chatHistoryDatabase: testChatHistory.database,
      failureReporter: failureReporter,
      composition: composition,
    );
    return _OrchestratorHarness(
      plugins: plugins,
      lifecycleService: lifecycleService,
      composition: composition,
      runtime: runtime,
      database: database,
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

  Future<void> activatePlugins() async {
    for (final plugin in plugins) {
      await activateTestPlugin(service: lifecycleService, pluginId: plugin.id);
    }

    final ready = Completer<void>();
    final subscription = composition.session.localWireEvents.where((event) => event is SesoriVcsBranchUpdated).listen((
      _,
    ) {
      if (!ready.isCompleted) ready.complete();
    });
    try {
      for (var attempt = 0; attempt < 200 && !ready.isCompleted; attempt++) {
        plugins.first.emitEvent(const BridgeSseVcsBranchUpdated());
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      if (!ready.isCompleted) throw TimeoutException("Plugin event subscription did not start");
    } finally {
      await subscription.cancel();
    }
  }
}

class _SourcedPlugin(final String pluginId) extends FakeBridgePlugin {
  Completer<void>? getProjectStarted;
  Completer<void>? getProjectGate;
  Completer<void>? activeSummaryReadStarted;
  Completer<void>? deleteSessionStarted;
  Completer<void>? deleteSessionGate;
  List<PluginProjectActivitySummary> activitySummaries = const [];

  @override
  String get id => pluginId;

  @override
  Future<PluginProject> getProject(String projectId) async {
    if (getProjectStarted case final started?) {
      getProjectStarted = null;
      final gate = getProjectGate;
      getProjectGate = null;
      started.complete();
      if (gate != null) await gate.future;
    }
    return await super.getProject(projectId);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    deleteSessionStarted?.complete();
    if (deleteSessionGate case final gate?) await gate.future;
    await super.deleteSession(sessionId);
  }

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    activeSummaryReadStarted?.complete();
    activeSummaryReadStarted = null;
    return activitySummaries;
  }
}
