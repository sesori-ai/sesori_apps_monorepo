import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_cubit.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_state.dart";
import "package:sesori_dart_core/src/errors/remote_failure_reason.dart";
import "package:sesori_dart_core/src/services/new_session_selection_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

const pluginA = PluginMetadata(
  id: "plugin-a",
  displayName: "Plugin A",
  isDefault: true,
  state: PluginLifecycleState.ready,
  actionHint: null,
);
const pluginB = PluginMetadata(
  id: "plugin-b",
  displayName: "Plugin B",
  isDefault: false,
  state: PluginLifecycleState.ready,
  actionHint: null,
);
const connectedStatus = ConnectionStatus.connected(
  config: ServerConnectionConfig(relayHost: "relay.example.com"),
  health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: null),
);

void main() {
  group("NewSessionCubit plugin selection", () {
    late MockSessionService sessionService;
    late MockPluginRepository pluginRepository;
    late MockConnectionService connectionService;
    late BehaviorSubject<ConnectionStatus> connectionStatus;
    late NewSessionSelectionTracker selectionTracker;

    setUp(() {
      sessionService = MockSessionService();
      pluginRepository = MockPluginRepository();
      connectionService = MockConnectionService();
      connectionStatus = BehaviorSubject.seeded(connectedStatus);
      selectionTracker = NewSessionSelectionTracker();
      when(() => connectionService.status).thenAnswer((_) => connectionStatus.stream);
      when(() => connectionService.currentStatus).thenAnswer((_) => connectionStatus.value);
      _stubEmptyResources(sessionService);
    });

    tearDown(() => connectionStatus.close());

    NewSessionCubit buildCubit() => NewSessionCubit(
      connectionService: connectionService,
      sessionService: sessionService,
      pluginRepository: pluginRepository,
      selectionTracker: selectionTracker,
      projectId: "project-1",
    );

    test("discovery error recovers after a reconnect", () async {
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        if (discoveryCalls == 1) {
          return ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null));
        }
        return ApiResponse.success(const PluginListResponse(plugins: [pluginA]));
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitUntil(() => cubit.state is NewSessionError);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() {
        final data = cubit.state.agentModelData;
        return data?.plugin?.id == "plugin-a" && !(data?.isLoading ?? true);
      });

      expect(discoveryCalls, 2);
      expect(cubit.state, isA<NewSessionIdle>());
      expect(cubit.state.agentModelData?.plugin, pluginA);
    });

    test("reconnect refreshes metadata, preserving a routable selection before falling back to default", () async {
      const refreshedDefault = PluginMetadata(
        id: "plugin-c",
        displayName: "Plugin C",
        isDefault: true,
        state: PluginLifecycleState.ready,
        actionHint: null,
      );
      const refreshedB = PluginMetadata(
        id: "plugin-b",
        displayName: "Plugin B refreshed",
        isDefault: false,
        state: PluginLifecycleState.degraded,
        actionHint: "Check the bridge console.",
      );
      const unavailableB = PluginMetadata(
        id: "plugin-b",
        displayName: "Plugin B unavailable",
        isDefault: false,
        state: PluginLifecycleState.unavailable,
        actionHint: "Start the plugin.",
      );
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        return switch (discoveryCalls) {
          1 => ApiResponse.success(const PluginListResponse(plugins: [pluginA, pluginB])),
          2 => ApiResponse.success(const PluginListResponse(plugins: [refreshedDefault, refreshedB])),
          _ => ApiResponse.success(const PluginListResponse(plugins: [refreshedDefault, unavailableB])),
        };
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      expect(discoveryCalls, 1);

      cubit.selectPlugin(pluginId: "plugin-b");
      await _waitForComposer(cubit);
      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() {
        final data = cubit.state.agentModelData;
        return data?.plugin == refreshedB && !(data?.isLoading ?? true);
      });

      expect(discoveryCalls, 2);
      expect(cubit.state.agentModelData?.plugins, [refreshedDefault, refreshedB]);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() {
        final data = cubit.state.agentModelData;
        return data?.plugin == refreshedDefault && !(data?.isLoading ?? true);
      });

      expect(discoveryCalls, 3);
      expect(cubit.state.agentModelData?.plugins, [refreshedDefault, unavailableB]);
    });

    test("reconnect discovery cannot be superseded by a stale plugin selection", () async {
      const unavailableB = PluginMetadata(
        id: "plugin-b",
        displayName: "Plugin B unavailable",
        isDefault: false,
        state: PluginLifecycleState.unavailable,
        actionHint: "Start the plugin.",
      );
      final reconnectDiscovery = Completer<ApiResponse<PluginListResponse>>();
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) {
        discoveryCalls++;
        if (discoveryCalls == 1) {
          return Future.value(ApiResponse.success(const PluginListResponse(plugins: [pluginA, pluginB])));
        }
        return reconnectDiscovery.future;
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() => discoveryCalls == 2);

      expect(cubit.state.agentModelData?.isLoading, isTrue);
      expect(cubit.state.agentModelData?.isPluginDiscoveryInFlight, isTrue);
      cubit.selectPlugin(pluginId: "plugin-b");
      expect(cubit.state.agentModelData?.plugin, pluginA);

      reconnectDiscovery.complete(
        ApiResponse.success(const PluginListResponse(plugins: [pluginA, unavailableB])),
      );
      await _waitUntil(() {
        final data = cubit.state.agentModelData;
        return data?.plugins.last == unavailableB && !(data?.isLoading ?? true);
      });

      expect(cubit.state.agentModelData?.plugin, pluginA);
      expect(cubit.state.agentModelData?.isPluginDiscoveryInFlight, isFalse);
      verifyNever(() => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-b"));
    });

    test("reconnect preserves and refreshes a staged command for the same plugin", () async {
      const refreshedA = PluginMetadata(
        id: "plugin-a",
        displayName: "Plugin A refreshed",
        isDefault: true,
        state: PluginLifecycleState.ready,
        actionHint: null,
      );
      final originalCommand = testCommandInfo();
      final refreshedCommand = testCommandInfo(template: "/review {{path}}");
      final refreshedCommands = Completer<ApiResponse<CommandListResponse>>();
      var discoveryCalls = 0;
      var commandCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        return ApiResponse.success(
          PluginListResponse(plugins: [discoveryCalls == 1 ? pluginA : refreshedA]),
        );
      });
      when(
        () => sessionService.listCommands(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) {
        commandCalls++;
        if (commandCalls == 1) {
          return Future.value(ApiResponse.success(CommandListResponse(items: [originalCommand])));
        }
        return refreshedCommands.future;
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.stageCommand(originalCommand);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() => cubit.state.agentModelData?.plugin == refreshedA);

      expect(cubit.state.agentModelData?.isLoading, isTrue);
      expect(cubit.state.agentModelData?.stagedCommand, originalCommand);

      refreshedCommands.complete(ApiResponse.success(CommandListResponse(items: [refreshedCommand])));
      await _waitForComposer(cubit);

      expect(cubit.state.agentModelData?.stagedCommand, refreshedCommand);
    });

    test("reconnect clears a staged command removed from the same plugin", () async {
      final command = testCommandInfo();
      final refreshedCommands = Completer<ApiResponse<CommandListResponse>>();
      var commandCalls = 0;
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(const PluginListResponse(plugins: [pluginA])));
      when(
        () => sessionService.listCommands(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) {
        commandCalls++;
        if (commandCalls == 1) {
          return Future.value(ApiResponse.success(CommandListResponse(items: [command])));
        }
        return refreshedCommands.future;
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.stageCommand(command);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() => cubit.state.agentModelData?.isLoading == true);

      expect(cubit.state.agentModelData?.stagedCommand, command);

      refreshedCommands.complete(ApiResponse.success(const CommandListResponse(items: [])));
      await _waitForComposer(cubit);

      expect(cubit.state.agentModelData?.stagedCommand, isNull);
    });

    test("reconnect clears a staged command immediately when the plugin falls back", () async {
      const initialB = PluginMetadata(
        id: "plugin-b",
        displayName: "Plugin B",
        isDefault: true,
        state: PluginLifecycleState.ready,
        actionHint: null,
      );
      const unavailableB = PluginMetadata(
        id: "plugin-b",
        displayName: "Plugin B unavailable",
        isDefault: false,
        state: PluginLifecycleState.unavailable,
        actionHint: "Start the plugin.",
      );
      final command = testCommandInfo();
      final fallbackAgents = Completer<ApiResponse<Agents>>();
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        return discoveryCalls == 1
            ? ApiResponse.success(const PluginListResponse(plugins: [initialB]))
            : ApiResponse.success(const PluginListResponse(plugins: [pluginA, unavailableB]));
      });
      when(
        () => sessionService.listCommands(projectId: "project-1", pluginId: "plugin-b"),
      ).thenAnswer((_) async => ApiResponse.success(CommandListResponse(items: [command])));
      when(
        () => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) => fallbackAgents.future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.stageCommand(command);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() => cubit.state.agentModelData?.plugin?.id == "plugin-a");

      expect(cubit.state.agentModelData?.isLoading, isTrue);
      expect(cubit.state.agentModelData?.stagedCommand, isNull);

      fallbackAgents.complete(ApiResponse.success(const Agents(agents: [])));
      await _waitForComposer(cubit);
    });

    test("connection changes have no effects after close", () async {
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        return ApiResponse.success(const PluginListResponse(plugins: [pluginA]));
      });
      final cubit = buildCubit();
      await _waitForComposer(cubit);
      final stateBeforeClose = cubit.state;
      expect(connectionStatus.hasListener, isTrue);

      await cubit.close();
      expect(connectionStatus.hasListener, isFalse);
      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await Future<void>.delayed(Duration.zero);

      expect(discoveryCalls, 1);
      expect(cubit.state, stateBeforeClose);
    });

    test("initial state has no synthetic selection and waits for discovery", () {
      when(pluginRepository.listPlugins).thenAnswer((_) => Completer<ApiResponse<PluginListResponse>>().future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      final state = cubit.state as NewSessionIdle;

      expect(state.availablePlugins, isEmpty);
      expect(state.selectedPlugin, isNull);
      expect(state.isComposerDataLoading, isTrue);
      expect(state.isPluginDiscoveryInFlight, isTrue);
      expect(state.availableAgents, isEmpty);
      expect(state.availableProviders, isEmpty);
      expect(state.availableCommands, isEmpty);
    });

    test("discovery failure is explicit and never synthesizes plugin metadata", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
      );

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitUntil(() => cubit.state is NewSessionError);

      final state = cubit.state as NewSessionError;
      expect(state.reason, RemoteFailureReason.serverRejected);
      expect(state.availablePlugins, isEmpty);
      expect(state.selectedPlugin, isNull);
      expect(state.isComposerDataLoading, isFalse);
      expect(state.isPluginDiscoveryInFlight, isFalse);
      expect(state.availableAgents, isEmpty);
      expect(state.availableProviders, isEmpty);
      expect(state.availableCommands, isEmpty);
      _verifyNoComposerCalls(sessionService);
    });

    test("closed cubit ignores a late discovery completion", () async {
      final discovery = Completer<ApiResponse<PluginListResponse>>();
      when(pluginRepository.listPlugins).thenAnswer((_) => discovery.future);
      final cubit = buildCubit();

      await cubit.close();
      discovery.complete(ApiResponse.success(const PluginListResponse(plugins: [pluginA])));
      await discovery.future;
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.agentModelData?.plugins, isEmpty);
      _verifyNoComposerCalls(sessionService);
    });

    test("preserves bridge order and selects a non-first server default", () async {
      const first = PluginMetadata(
        id: "blocked",
        displayName: "Blocked",
        isDefault: false,
        state: PluginLifecycleState.failed,
        actionHint: "Restart the bridge.",
      );
      const second = PluginMetadata(
        id: "selected",
        displayName: "Selected",
        isDefault: true,
        state: PluginLifecycleState.ready,
        actionHint: null,
      );
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(const PluginListResponse(plugins: [first, second])),
      );

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);

      final state = cubit.state as NewSessionIdle;
      expect(state.availablePlugins.map((plugin) => plugin.id), ["blocked", "selected"]);
      expect(state.selectedPlugin, second);
      verify(() => sessionService.listAgents(projectId: "project-1", pluginId: "selected")).called(1);
      verify(() => sessionService.listProviders(projectId: "project-1", pluginId: "selected")).called(1);
      verify(() => sessionService.listCommands(projectId: "project-1", pluginId: "selected")).called(1);
    });

    test("degraded default is routable and all create resources use its explicit id", () async {
      const degraded = PluginMetadata(
        id: "degraded",
        displayName: "Degraded",
        isDefault: true,
        state: PluginLifecycleState.degraded,
        actionHint: "Check the bridge console.",
      );
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(const PluginListResponse(plugins: [degraded])),
      );
      when(
        () => sessionService.createSessionWithMessage(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          providerID: any(named: "providerID"),
          modelID: any(named: "modelID"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(testSession(pluginId: "degraded")));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      await cubit.createSession(text: "hello", dedicatedWorktree: true, command: null);

      verify(() => sessionService.listAgents(projectId: "project-1", pluginId: "degraded")).called(1);
      verify(() => sessionService.listProviders(projectId: "project-1", pluginId: "degraded")).called(1);
      verify(() => sessionService.listCommands(projectId: "project-1", pluginId: "degraded")).called(1);
      verify(
        () => sessionService.createSessionWithMessage(
          projectId: "project-1",
          pluginId: "degraded",
          text: "hello",
          agent: null,
          providerID: null,
          modelID: null,
          variant: null,
          command: null,
          dedicatedWorktree: true,
        ),
      ).called(1);
    });

    test("unavailable and failed plugins remain visible but cannot load or create", () async {
      const unavailable = PluginMetadata(
        id: "unavailable",
        displayName: "Unavailable",
        isDefault: true,
        state: PluginLifecycleState.unavailable,
        actionHint: "Check the bridge console.",
      );
      const failed = PluginMetadata(
        id: "failed",
        displayName: "Failed",
        isDefault: false,
        state: PluginLifecycleState.failed,
        actionHint: "Restart the bridge.",
      );
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(const PluginListResponse(plugins: [unavailable, failed])),
      );

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitUntil(() => cubit.state.agentModelData?.isLoading == false);

      final state = cubit.state as NewSessionIdle;
      expect(state.availablePlugins, [unavailable, failed]);
      expect(state.selectedPlugin, unavailable);
      cubit.selectPlugin(pluginId: "failed");
      cubit.selectPlugin(pluginId: "unknown");
      await cubit.createSession(text: "blocked", dedicatedWorktree: true, command: null);

      expect((cubit.state as NewSessionIdle).selectedPlugin, unavailable);
      _verifyNoComposerCalls(sessionService);
      verifyNever(
        () => sessionService.createSessionWithMessage(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          providerID: any(named: "providerID"),
          modelID: any(named: "modelID"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      );
    });

    test("absent default does not load or create until the user selects a plugin", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(const PluginListResponse(plugins: [pluginB])),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitUntil(() => cubit.state.agentModelData?.isLoading == false);

      expect(cubit.state.agentModelData?.plugin, isNull);
      await cubit.createSession(text: "blocked", dedicatedWorktree: true, command: null);
      _verifyNoComposerCalls(sessionService);

      cubit.selectPlugin(pluginId: "plugin-b");
      await _waitForComposer(cubit);
      verify(() => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-b")).called(1);
    });

    test("plugin switch clears backend-local composer state synchronously", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(const PluginListResponse(plugins: [pluginA, pluginB])),
      );
      final bAgents = Completer<ApiResponse<Agents>>();
      when(
        () => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) async => ApiResponse.success(Agents(agents: [_agent("agent-a")])));
      when(
        () => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-b"),
      ).thenAnswer((_) => bAgents.future);
      when(
        () => sessionService.listProviders(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) async => ApiResponse.success(_providerResponse()));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.selectVariant(const SessionVariant(id: "high"));
      cubit.stageCommand(testCommandInfo());

      cubit.selectPlugin(pluginId: "plugin-b");

      final state = cubit.state as NewSessionIdle;
      expect(state.selectedPlugin?.id, "plugin-b");
      expect(state.isComposerDataLoading, isTrue);
      expect(state.isPluginDiscoveryInFlight, isFalse);
      expect(state.availableAgents, isEmpty);
      expect(state.availableProviders, isEmpty);
      expect(state.availableCommands, isEmpty);
      expect(state.selectedAgent, isNull);
      expect(state.selectedAgentModel, isNull);
      expect(state.availableVariants, isEmpty);
      expect(state.stagedCommand, isNull);
      bAgents.complete(ApiResponse.success(const Agents(agents: [])));
    });

    test("A-B rejects late A resource completion", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(const PluginListResponse(plugins: [pluginA, pluginB])),
      );
      final a = Completer<ApiResponse<Agents>>();
      final b = Completer<ApiResponse<Agents>>();
      when(
        () => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) => a.future);
      when(
        () => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-b"),
      ).thenAnswer((_) => b.future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitUntil(() => cubit.state.agentModelData?.plugin?.id == "plugin-a");
      cubit.selectPlugin(pluginId: "plugin-b");
      b.complete(ApiResponse.success(Agents(agents: [_agent("agent-b")])));
      await _waitForComposer(cubit);
      a.complete(ApiResponse.success(Agents(agents: [_agent("late-agent-a")])));
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as NewSessionIdle;
      expect(state.selectedPlugin?.id, "plugin-b");
      expect(state.availableAgents.map((agent) => agent.name), ["agent-b"]);
    });

    test("A-B-A rejects both late original A and B completions", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(const PluginListResponse(plugins: [pluginA, pluginB])),
      );
      final firstA = Completer<ApiResponse<Agents>>();
      final secondA = Completer<ApiResponse<Agents>>();
      final b = Completer<ApiResponse<Agents>>();
      var aCalls = 0;
      when(
        () => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) => aCalls++ == 0 ? firstA.future : secondA.future);
      when(
        () => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-b"),
      ).thenAnswer((_) => b.future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitUntil(() => cubit.state.agentModelData?.plugin?.id == "plugin-a");
      cubit.selectPlugin(pluginId: "plugin-b");
      cubit.selectPlugin(pluginId: "plugin-a");
      secondA.complete(ApiResponse.success(Agents(agents: [_agent("fresh-agent-a")])));
      await _waitForComposer(cubit);
      b.complete(ApiResponse.success(Agents(agents: [_agent("late-agent-b")])));
      firstA.complete(ApiResponse.success(Agents(agents: [_agent("old-agent-a")])));
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as NewSessionIdle;
      expect(state.selectedPlugin?.id, "plugin-a");
      expect(state.availableAgents.map((agent) => agent.name), ["fresh-agent-a"]);
    });

    test("restores selection only from the matching project-plugin key", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(const PluginListResponse(plugins: [pluginA, pluginB])),
      );
      selectionTracker
        ..write(projectId: "project-1", pluginId: "plugin-a", agent: "agent-a", agentModel: null)
        ..write(projectId: "project-1", pluginId: "plugin-b", agent: "agent-b", agentModel: null);
      when(
        () => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) async => ApiResponse.success(Agents(agents: [_agent("agent-a")])));
      when(
        () => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-b"),
      ).thenAnswer((_) async => ApiResponse.success(Agents(agents: [_agent("agent-b")])));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      expect(cubit.state.agentModelData?.agent, "agent-a");

      cubit.selectPlugin(pluginId: "plugin-b");
      await _waitForComposer(cubit);
      expect(cubit.state.agentModelData?.agent, "agent-b");
    });

    test("successful creation clears only its matching plugin snapshot", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(const PluginListResponse(plugins: [pluginA, pluginB])),
      );
      selectionTracker
        ..write(projectId: "project-1", pluginId: "plugin-a", agent: "agent-a", agentModel: null)
        ..write(projectId: "project-1", pluginId: "plugin-b", agent: "agent-b", agentModel: null);
      when(
        () => sessionService.createSessionWithMessage(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          providerID: any(named: "providerID"),
          modelID: any(named: "modelID"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(testSession(pluginId: "plugin-a")));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      await cubit.createSession(text: "hello", dedicatedWorktree: true, command: null);

      expect(selectionTracker.read(projectId: "project-1", pluginId: "plugin-a"), isNull);
      expect(selectionTracker.read(projectId: "project-1", pluginId: "plugin-b")?.agent, "agent-b");
    });
  });
}

void _stubEmptyResources(MockSessionService sessionService) {
  when(
    () => sessionService.listAgents(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer((_) async => ApiResponse.success(const Agents(agents: [])));
  when(
    () => sessionService.listProviders(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (_) async => ApiResponse.success(const ProviderListResponse(items: [], connectedOnly: false)),
  );
  when(
    () => sessionService.listCommands(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer((_) async => ApiResponse.success(const CommandListResponse(items: [])));
}

void _verifyNoComposerCalls(MockSessionService sessionService) {
  verifyNever(
    () => sessionService.listAgents(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  );
  verifyNever(
    () => sessionService.listProviders(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  );
  verifyNever(
    () => sessionService.listCommands(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  );
}

AgentInfo _agent(String name) {
  return AgentInfo(name: name, description: name, model: null, mode: AgentMode.primary);
}

ProviderListResponse _providerResponse() {
  return const ProviderListResponse(
    connectedOnly: false,
    items: [
      ProviderInfo(
        id: "provider",
        name: "Provider",
        models: {
          "model": ProviderModel(
            id: "model",
            providerID: "provider",
            name: "Model",
            variants: ["high"],
            family: null,
            releaseDate: null,
          ),
        },
        defaultModelID: "model",
      ),
    ],
  );
}

Future<void> _waitForComposer(NewSessionCubit cubit) {
  return _waitUntil(() => cubit.state.agentModelData?.isLoading == false);
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail("Condition was not reached");
}
