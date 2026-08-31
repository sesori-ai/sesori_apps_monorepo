import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_cubit.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_state.dart";
import "package:sesori_dart_core/src/errors/remote_failure_reason.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/foundation/models/session_options/session_options_request_mode.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_discovery_snapshot.dart";
import "package:sesori_dart_core/src/repositories/models/session_options_repository_result.dart";
import "package:sesori_dart_core/src/services/models/new_session_options_source.dart";
import "package:sesori_dart_core/src/services/models/new_session_selection_intent.dart";
import "package:sesori_dart_core/src/services/new_session_options_service.dart";
import "package:sesori_dart_core/src/services/new_session_plugin_service.dart";
import "package:sesori_dart_core/src/services/new_session_selection_tracker.dart";
import "package:sesori_dart_core/src/utils/model_filter/default_model_selector.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";
import "new_session_state_matchers.dart";

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
  config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
  health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false),
);

PluginDiscoverySnapshot _pluginSnapshot({
  required String? bridgeId,
  required List<PluginMetadata> plugins,
}) => PluginDiscoverySnapshot(
  bridgeId: bridgeId,
  supportsSessionOptions: false,
  plugins: plugins,
);

final class _AggregateTestOptionsService({required MockSessionRepository sessionRepository})
    extends NewSessionOptionsService {
  this
    : super(
        sessionRepository: sessionRepository,
        defaultModelSelector: const DefaultModelSelector(),
      );

  @override
  Future<NewSessionOptionsLoadResult> load({
    required String projectId,
    required String pluginId,
    required NewSessionOptionsSource source,
    required NewSessionOptionsLoadMode mode,
    required NewSessionSelectionIntent? restoredSelection,
    required NewSessionOptionsData? previousOptions,
  }) {
    return super.load(
      projectId: projectId,
      pluginId: pluginId,
      source: NewSessionOptionsSource.aggregate,
      mode: mode,
      restoredSelection: restoredSelection,
      previousOptions: previousOptions,
    );
  }
}

void main() {
  group("NewSessionCubit plugin selection", () {
    late MockSessionRepository sessionService;
    late MockSessionRepository sessionRepository;
    late MockPluginRepository pluginRepository;
    late MockPluginPreferenceRepository pluginPreferenceRepository;
    late MockProjectRepository projectRepository;
    late MockConnectionService connectionService;
    late BehaviorSubject<ConnectionStatus> connectionStatus;
    late NewSessionSelectionTracker selectionTracker;

    setUpAll(registerAllFallbackValues);

    setUp(() {
      sessionService = MockSessionRepository();
      sessionRepository = MockSessionRepository();
      pluginRepository = MockPluginRepository();
      pluginPreferenceRepository = MockPluginPreferenceRepository();
      projectRepository = MockProjectRepository();
      connectionService = MockConnectionService();
      connectionStatus = BehaviorSubject.seeded(connectedStatus);
      selectionTracker = NewSessionSelectionTracker();
      when(() => connectionService.status).thenAnswer((_) => connectionStatus.stream);
      when(() => connectionService.currentStatus).thenAnswer((_) => connectionStatus.value);
      when(
        () => pluginPreferenceRepository.readPluginId(bridgeId: any(named: "bridgeId")),
      ).thenAnswer((_) async => null);
      when(
        () => pluginPreferenceRepository.writePluginId(
          bridgeId: any(named: "bridgeId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async {});
      when(
        () => projectRepository.getProject(projectId: any(named: "projectId")),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const Project(
            id: "project-1",
            name: "Project",
            path: "/project",
            time: null,
            supportsDedicatedWorktrees: true,
            voiceGlossaryKey: null,
          ),
        ),
      );
      _stubEmptyResources(sessionService);
      delegateSessionOptionsRepository(
        repository: sessionRepository,
        source: sessionService,
      );
    });

    tearDown(() => connectionStatus.close());

    NewSessionCubit buildCubit({NewSessionOptionsService? optionsService}) => NewSessionCubit(
      connectionService: connectionService,
      sessionRepository: sessionService,
      newSessionPluginService: NewSessionPluginService(
        pluginRepository: pluginRepository,
        pluginPreferenceRepository: pluginPreferenceRepository,
      ),
      newSessionOptionsService: optionsService ?? _AggregateTestOptionsService(sessionRepository: sessionRepository),
      projectRepository: projectRepository,
      selectionTracker: selectionTracker,
      composerDraftRepository: inMemoryComposerDraftRepository(),
      productAnalyticsService: stubbedProductAnalyticsService(),
      projectId: "project-1",
    );

    void establishSelectionScope({required String bridgeId}) {
      selectionTracker.applyBackendScopeTransition(
        transition: selectionTracker.backendScope.transitionToDiscovered(bridgeId: bridgeId),
      );
    }

    test("discovery error recovers after a reconnect", () async {
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        if (discoveryCalls == 1) {
          return ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null));
        }
        return ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA]));
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitUntil(() => cubit.state.phase is NewSessionPhaseDiscoveryError);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() {
        final data = cubit.state.agentModelData;
        return data?.plugin?.id == "plugin-a" && !(data?.isLoading ?? true);
      });

      expect(discoveryCalls, 2);
      expect(cubit.state, composingWith<NewSessionPhaseIdle>());
      expect(cubit.state.agentModelData?.plugin, pluginA);
    });

    test("reconnect discovery failure preserves usable composer data in the error state", () async {
      final command = testCommandInfo();
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        if (discoveryCalls == 1) {
          return ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA, pluginB]));
        }
        return ApiResponse.error(ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null));
      });
      when(
        () => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) async => ApiResponse.success(Agents(agents: [_agent("agent-a")])));
      when(
        () => sessionService.listProviders(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) async => ApiResponse.success(_providerResponse()));
      when(
        () => sessionService.listCommands(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) async => ApiResponse.success(CommandListResponse(items: [command])));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.selectVariant(const SessionVariant(id: "high"));
      cubit.stageCommand(command);
      final beforeRefresh = cubit.state.agentModelData!;

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() {
        final data = cubit.state.agentModelData;
        return cubit.state.phase is NewSessionPhaseDiscoveryError && !(data?.isLoading ?? true);
      });

      final state = cubit.state as NewSessionComposing;
      final afterRefresh = state.agentModelData!;
      expect((state.phase as NewSessionPhaseDiscoveryError).reason, RemoteFailureReason.serverRejected);
      expect(afterRefresh.plugins, beforeRefresh.plugins);
      expect(afterRefresh.plugin, beforeRefresh.plugin);
      expect(afterRefresh.agents, beforeRefresh.agents);
      expect(afterRefresh.providers, beforeRefresh.providers);
      expect(afterRefresh.commands, beforeRefresh.commands);
      expect(afterRefresh.agent, beforeRefresh.agent);
      expect(afterRefresh.agentModel, beforeRefresh.agentModel);
      expect(afterRefresh.availableVariants, beforeRefresh.availableVariants);
      expect(afterRefresh.stagedCommand, beforeRefresh.stagedCommand);
      expect(afterRefresh.isLoading, isFalse);
      expect(afterRefresh.isPluginDiscoveryInFlight, isFalse);

      cubit.selectPlugin(pluginId: "plugin-b");
      expect(cubit.state, composingWith<NewSessionPhaseDiscoveryError>());
      expect(cubit.state.agentModelData?.plugin, pluginA);

      cubit.clearStagedCommand();
      expect(cubit.state.agentModelData?.stagedCommand, isNull);
    });

    test("reconnect reloads project capability and failure blocks creation as unavailable", () async {
      final refresh = Completer<ApiResponse<Project>>();
      var projectCalls = 0;
      when(
        () => projectRepository.getProject(projectId: "project-1"),
      ).thenAnswer((_) {
        projectCalls++;
        if (projectCalls == 1) {
          return Future.value(
            ApiResponse.success(
              const Project(
                id: "project-1",
                name: "Project",
                path: "/project",
                time: null,
                supportsDedicatedWorktrees: true,
                voiceGlossaryKey: null,
              ),
            ),
          );
        }
        return refresh.future;
      });
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      expect(
        cubit.state.agentModelData?.projectWorktreeCapability,
        NewSessionProjectWorktreeCapability.supported,
      );

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() => projectCalls == 2);
      expect(
        cubit.state.agentModelData?.projectWorktreeCapability,
        NewSessionProjectWorktreeCapability.loading,
      );
      expect(cubit.canCreateSession, isFalse);
      refresh.complete(ApiResponse.error(ApiError.generic()));
      await _waitForComposer(cubit);
      await Future<void>.delayed(Duration.zero);

      expect(
        cubit.state.agentModelData?.projectWorktreeCapability,
        NewSessionProjectWorktreeCapability.unavailable,
      );
      expect(cubit.canCreateSession, isFalse);
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
          1 => ApiResponse.success(_pluginSnapshot(bridgeId: "br_test", plugins: [pluginA, pluginB])),
          2 => ApiResponse.success(
            _pluginSnapshot(bridgeId: "br_test", plugins: [refreshedDefault, refreshedB]),
          ),
          _ => ApiResponse.success(
            _pluginSnapshot(bridgeId: "br_test", plugins: [refreshedDefault, unavailableB]),
          ),
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
      final reconnectDiscovery = Completer<ApiResponse<PluginDiscoverySnapshot>>();
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) {
        discoveryCalls++;
        if (discoveryCalls == 1) {
          return Future.value(
            ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA, pluginB])),
          );
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
        ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA, unavailableB])),
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
          PluginDiscoverySnapshot(
            bridgeId: "bridge-a",
            supportsSessionOptions: true,
            plugins: [discoveryCalls == 1 ? pluginA : refreshedA],
          ),
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
      ).thenAnswer(
        (_) async => ApiResponse.success(
          PluginDiscoverySnapshot(
            bridgeId: "bridge-a",
            supportsSessionOptions: true,
            plugins: const [pluginA],
          ),
        ),
      );
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
      await _waitUntil(() => cubit.state.agentModelData?.isLoading ?? false);

      expect(cubit.state.agentModelData?.stagedCommand, command);

      refreshedCommands.complete(ApiResponse.success(const CommandListResponse(items: [])));
      await _waitForComposer(cubit);

      expect(cubit.state.agentModelData?.stagedCommand, isNull);
    });

    test("a cache the bridge reports stale refreshes without a visible loading state", () async {
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])));
      final refreshed = Completer<SessionOptionsRepositoryResult>();
      final modes = <SessionOptionsRequestMode>[];
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((invocation) async {
        modes.add(invocation.namedArguments[#mode]! as SessionOptionsRequestMode);
        return modes.length == 1
            ? _optionsCatalog(agentName: "stale-agent", providers: const [], isStale: true)
            : await refreshed.future;
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);

      expect(modes, [SessionOptionsRequestMode.dynamic, SessionOptionsRequestMode.forceRefresh]);
      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsAvailableState>());
      expect(cubit.state.agentModelData?.agents.single.name, "stale-agent");

      refreshed.complete(_optionsCatalog(agentName: "fresh-agent", providers: const [], isStale: false));
      await _waitUntil(() => cubit.state.agentModelData?.agents.single.name == "fresh-agent");

      expect(modes, hasLength(2));
    });

    test("an explicit refresh joins the silent one instead of asking the bridge twice", () async {
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])));
      final refreshed = Completer<SessionOptionsRepositoryResult>();
      var loadCalls = 0;
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((_) async {
        loadCalls++;
        return loadCalls == 1
            ? _optionsCatalog(agentName: "stale-agent", providers: const [], isStale: true)
            : await refreshed.future;
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      expect(loadCalls, 2);

      final explicitRefresh = cubit.refreshOptions();

      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsRefreshingState>());
      expect(loadCalls, 2);

      refreshed.complete(_optionsCatalog(agentName: "fresh-agent", providers: const [], isStale: false));
      await explicitRefresh;

      expect(loadCalls, 2);
      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsAvailableState>());
      expect(cubit.state.agentModelData?.agents.single.name, "fresh-agent");
    });

    test("a failed background refresh keeps the options it was refreshing", () async {
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])));
      final refreshed = Completer<SessionOptionsRepositoryResult>();
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((invocation) async {
        return invocation.namedArguments[#mode] == SessionOptionsRequestMode.dynamic
            ? _optionsCatalog(agentName: "cached-agent", providers: const [], isStale: true)
            : await refreshed.future;
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);

      refreshed.complete(const SessionOptionsRepositoryRefreshFailedUnavailable());
      await _settle();

      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsFailureRetainedState>());
      expect(cubit.state.agentModelData?.agents.single.name, "cached-agent");
      expect(cubit.canCreateSession, isTrue);
    });

    test("a background refresh from a superseded selection is not joined", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA, pluginB])),
      );
      // Plugin A's background refresh never answers, so joining it would leave
      // an explicit refresh for plugin B running forever.
      final strandedRefresh = Completer<SessionOptionsRepositoryResult>();
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((invocation) async {
        return invocation.namedArguments[#mode] == SessionOptionsRequestMode.dynamic
            ? _optionsCatalog(agentName: "a-agent", providers: const [], isStale: true)
            : await strandedRefresh.future;
      });
      var pluginBRefreshes = 0;
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-b",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((invocation) async {
        if (invocation.namedArguments[#mode] == SessionOptionsRequestMode.forceRefresh) pluginBRefreshes++;
        return _optionsCatalog(agentName: "b-agent", providers: const [], isStale: false);
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);

      cubit.selectPlugin(pluginId: "plugin-b");
      await _waitForComposer(cubit);

      await cubit.refreshOptions();

      expect(pluginBRefreshes, 1);
      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsAvailableState>());
      expect(cubit.canCreateSession, isTrue);
    });

    test("a choice made during a background refresh outranks its result", () async {
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])));
      final refreshed = Completer<SessionOptionsRepositoryResult>();
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((invocation) async {
        return invocation.namedArguments[#mode] == SessionOptionsRequestMode.dynamic
            ? _optionsCatalog(agentName: "agent", providers: _providerResponse().items, isStale: true)
            : await refreshed.future;
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      expect(cubit.state.agentModelData?.agentModel?.variant, "high");

      cubit.selectVariant(const SessionVariant(id: "max"));
      expect(cubit.state.agentModelData?.agentModel?.variant, "max");

      refreshed.complete(
        _optionsCatalog(agentName: "refreshed-agent", providers: _providerResponse().items, isStale: false),
      );
      await _settle();

      expect(cubit.state.agentModelData?.agentModel?.variant, "max");
      expect(cubit.state.agentModelData?.agents.single.name, "agent");
      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsAvailableState>());
      expect(cubit.canCreateSession, isTrue);
    });

    test("typed retained refresh failure preserves the staged command and prior catalog", () async {
      final command = testCommandInfo();
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])));
      var loadCalls = 0;
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((_) async {
        loadCalls++;
        return loadCalls == 1
            ? SessionOptionsRepositoryAvailable(
                isStale: false,
                catalog: SessionOptionsCatalog(
                  agents: const [],
                  providers: const [],
                  providersConnectedOnly: false,
                  commands: [command],
                  lastUsedPromptDefaults: null,
                ),
              )
            : const SessionOptionsRepositoryRefreshFailedRetained();
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.stageCommand(command);

      await cubit.refreshOptions();

      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsFailureRetainedState>());
      expect(cubit.state.agentModelData?.commands, [command]);
      expect(cubit.state.agentModelData?.stagedCommand, command);
    });

    test("unexpected refresh exception preserves the prior catalog", () async {
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])));
      var loadCalls = 0;
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((_) async {
        loadCalls++;
        if (loadCalls > 1) throw StateError("unexpected refresh failure");
        return SessionOptionsRepositoryAvailable(
          isStale: false,
          catalog: SessionOptionsCatalog(
            agents: const [],
            providers: _providerResponse().items,
            providersConnectedOnly: false,
            commands: const [],
            lastUsedPromptDefaults: null,
          ),
        );
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      final previousModel = cubit.state.agentModelData?.agentModel;

      await cubit.refreshOptions();

      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsFailureRetainedState>());
      expect(cubit.state.agentModelData?.agentModel, previousModel);
      expect(cubit.state.agentModelData?.providers, isNotEmpty);
    });

    test("caught legacy refresh failure preserves the legacy source", () async {
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])));
      var legacyLoads = 0;
      when(
        () => sessionRepository.loadLegacySessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
        ),
      ).thenAnswer((_) async {
        legacyLoads++;
        if (legacyLoads == 2) throw StateError("unexpected legacy refresh failure");
        return LegacySessionOptionsRepositoryAvailable(
          catalog: SessionOptionsCatalog(
            agents: const [],
            providers: _providerResponse().items,
            providersConnectedOnly: false,
            commands: const [],
            lastUsedPromptDefaults: null,
          ),
        );
      });
      final cubit = buildCubit(
        optionsService: NewSessionOptionsService(
          sessionRepository: sessionRepository,
          defaultModelSelector: const DefaultModelSelector(),
        ),
      );
      addTearDown(cubit.close);
      await _waitForComposer(cubit);

      await cubit.refreshOptions();
      await cubit.refreshOptions();

      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsFailureRetainedState>());
      expect(cubit.state.agentModelData?.optionsState.source, NewSessionOptionsSource.legacy);

      await cubit.refreshOptions();
      expect(legacyLoads, 3);
      verifyNever(
        () => sessionRepository.loadSessionOptions(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          mode: any(named: "mode"),
        ),
      );
    });

    test("typed legacy refresh failure preserves prior options", () async {
      final command = testCommandInfo();
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])));
      var legacyLoads = 0;
      when(
        () => sessionRepository.loadLegacySessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
        ),
      ).thenAnswer((_) async {
        legacyLoads++;
        return legacyLoads == 1
            ? LegacySessionOptionsRepositoryAvailable(
                catalog: SessionOptionsCatalog(
                  agents: const [],
                  providers: const [],
                  providersConnectedOnly: false,
                  commands: [command],
                  lastUsedPromptDefaults: null,
                ),
              )
            : LegacySessionOptionsRepositoryFailure(
                errors: [
                  LegacySessionOptionError(
                    source: LegacySessionOptionSource.providers,
                    error: ApiError.generic(),
                  ),
                ],
              );
      });
      final cubit = buildCubit(
        optionsService: NewSessionOptionsService(
          sessionRepository: sessionRepository,
          defaultModelSelector: const DefaultModelSelector(),
        ),
      );
      addTearDown(cubit.close);
      await _waitForComposer(cubit);

      await cubit.refreshOptions();
      cubit.stageCommand(command);
      await cubit.refreshOptions();

      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsFailureRetainedState>());
      expect(cubit.state.agentModelData?.optionsState.source, NewSessionOptionsSource.legacy);
      expect(cubit.state.agentModelData?.commands, [command]);
      expect(cubit.state.agentModelData?.stagedCommand, command);
    });

    test("same-bridge reconnect retains options when aggregate reload fails", () async {
      final command = testCommandInfo();
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        return ApiResponse.success(
          PluginDiscoverySnapshot(
            bridgeId: "bridge-a",
            supportsSessionOptions: true,
            plugins: const [pluginA],
          ),
        );
      });
      var loadCalls = 0;
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((_) async {
        loadCalls++;
        return loadCalls == 1
            ? SessionOptionsRepositoryAvailable(
                isStale: false,
                catalog: SessionOptionsCatalog(
                  agents: const [],
                  providers: const [],
                  providersConnectedOnly: false,
                  commands: [command],
                  lastUsedPromptDefaults: null,
                ),
              )
            : SessionOptionsRepositoryFailure(error: ApiError.generic());
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.stageCommand(command);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() => discoveryCalls == 2 && cubit.state.agentModelData?.isLoading == false);

      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsFailureRetainedState>());
      expect(cubit.state.agentModelData?.commands, [command]);
      expect(cubit.state.agentModelData?.stagedCommand, command);
    });

    test("same-bridge reconnect reuses previously loaded legacy options", () async {
      final command = testCommandInfo();
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        return ApiResponse.success(_pluginSnapshot(bridgeId: "bridge-a", plugins: [pluginA]));
      });
      var legacyLoads = 0;
      when(
        () => sessionRepository.loadLegacySessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
        ),
      ).thenAnswer((_) async {
        legacyLoads++;
        return LegacySessionOptionsRepositoryAvailable(
          catalog: SessionOptionsCatalog(
            agents: const [],
            providers: const [],
            providersConnectedOnly: false,
            commands: [command],
            lastUsedPromptDefaults: null,
          ),
        );
      });
      final cubit = buildCubit(
        optionsService: NewSessionOptionsService(
          sessionRepository: sessionRepository,
          defaultModelSelector: const DefaultModelSelector(),
        ),
      );
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      await cubit.refreshOptions();
      cubit.stageCommand(command);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() => discoveryCalls == 2 && cubit.state.agentModelData?.isLoading == false);

      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsAvailableState>());
      expect(cubit.state.agentModelData?.optionsState.source, NewSessionOptionsSource.legacy);
      expect(cubit.state.agentModelData?.commands, [command]);
      expect(cubit.state.agentModelData?.stagedCommand, command);
      expect(legacyLoads, 1);
    });

    test("reconnect with an unidentified bridge drops legacy options", () async {
      final command = testCommandInfo();
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        return ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA]));
      });
      var legacyLoads = 0;
      when(
        () => sessionRepository.loadLegacySessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
        ),
      ).thenAnswer((_) async {
        legacyLoads++;
        return LegacySessionOptionsRepositoryAvailable(
          catalog: SessionOptionsCatalog(
            agents: const [],
            providers: const [],
            providersConnectedOnly: false,
            commands: [command],
            lastUsedPromptDefaults: null,
          ),
        );
      });
      final cubit = buildCubit(
        optionsService: NewSessionOptionsService(
          sessionRepository: sessionRepository,
          defaultModelSelector: const DefaultModelSelector(),
        ),
      );
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      await cubit.refreshOptions();
      cubit.stageCommand(command);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() => discoveryCalls == 2 && cubit.state.agentModelData?.isLoading == false);

      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsUnsupportedState>());
      expect(cubit.state.agentModelData?.commands, isEmpty);
      expect(cubit.state.agentModelData?.stagedCommand, isNull);
      expect(legacyLoads, 1);
    });

    test("same-bridge capability downgrade drops aggregate options", () async {
      final command = testCommandInfo();
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        return ApiResponse.success(
          PluginDiscoverySnapshot(
            bridgeId: "bridge-a",
            supportsSessionOptions: discoveryCalls == 1,
            plugins: const [pluginA],
          ),
        );
      });
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
          mode: any(named: "mode"),
        ),
      ).thenAnswer(
        (_) async => SessionOptionsRepositoryAvailable(
          isStale: false,
          catalog: SessionOptionsCatalog(
            agents: const [],
            providers: const [],
            providersConnectedOnly: false,
            commands: [command],
            lastUsedPromptDefaults: null,
          ),
        ),
      );

      final cubit = buildCubit(
        optionsService: NewSessionOptionsService(
          sessionRepository: sessionRepository,
          defaultModelSelector: const DefaultModelSelector(),
        ),
      );
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.stageCommand(command);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() => discoveryCalls == 2 && cubit.state.agentModelData?.isLoading == false);

      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsUnsupportedState>());
      expect(cubit.state.agentModelData?.commands, isEmpty);
      expect(cubit.state.agentModelData?.stagedCommand, isNull);
    });

    test("project-not-found refresh clears prior options", () async {
      final command = testCommandInfo();
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(_pluginSnapshot(bridgeId: "bridge-a", plugins: [pluginA])));
      var loadCalls = 0;
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((_) async {
        loadCalls++;
        return loadCalls == 1
            ? SessionOptionsRepositoryAvailable(
                isStale: false,
                catalog: SessionOptionsCatalog(
                  agents: const [],
                  providers: const [],
                  providersConnectedOnly: false,
                  commands: [command],
                  lastUsedPromptDefaults: null,
                ),
              )
            : SessionOptionsRepositoryProjectNotFound(error: ApiError.generic());
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.stageCommand(command);

      await cubit.refreshOptions();

      expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsFailureState>());
      expect(cubit.state.agentModelData?.commands, isEmpty);
      expect(cubit.state.agentModelData?.stagedCommand, isNull);
    });

    test("typed unavailable refresh failure clears the prior option catalog", () async {
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])));
      var loadCalls = 0;
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-a",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((_) async {
        loadCalls++;
        return loadCalls == 1
            ? SessionOptionsRepositoryAvailable(
                isStale: false,
                catalog: SessionOptionsCatalog(
                  agents: const [],
                  providers: _providerResponse().items,
                  providersConnectedOnly: false,
                  commands: const [],
                  lastUsedPromptDefaults: null,
                ),
              )
            : const SessionOptionsRepositoryRefreshFailedUnavailable();
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.selectVariant(const SessionVariant(id: "high"));
      final logLines = <String>[];
      await runZoned(
        cubit.refreshOptions,
        zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logLines.add(line)),
      );

      final afterRefresh = cubit.state.agentModelData!;
      expect(afterRefresh.optionsState, isA<NewSessionOptionsRefreshFailureUnavailableState>());
      expect(afterRefresh.providers, isEmpty);
      expect(afterRefresh.agentModel, isNull);
      expect(afterRefresh.availableVariants, isEmpty);
      expect(
        logLines,
        contains(
          "New session: options unavailable for plugin plugin-a "
          "(source: aggregate, mode: forcedRefresh, result: NewSessionOptionsRefreshFailureUnavailable)",
        ),
      );
    });

    test("failed provider load after a plugin switch does not restore the prior plugin catalog", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA, pluginB])),
      );
      when(
        () => sessionService.listProviders(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) async => ApiResponse.success(_providerResponse()));
      when(
        () => sessionService.listProviders(projectId: "project-1", pluginId: "plugin-b"),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      expect(cubit.state.agentModelData?.providers, isNotEmpty);

      cubit.selectPlugin(pluginId: "plugin-b");
      await _waitForComposer(cubit);

      expect(cubit.state.agentModelData?.plugin, pluginB);
      expect(cubit.state.agentModelData?.providers, isEmpty);
      expect(cubit.state.agentModelData?.agentModel, isNull);
      expect(cubit.state.agentModelData?.availableVariants, isEmpty);
    });

    test("successful provider refresh authoritatively removes missing selections", () async {
      var providerCalls = 0;
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])));
      when(
        () => sessionService.listProviders(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) async {
        providerCalls++;
        return ApiResponse.success(
          providerCalls == 1 ? _providerResponse() : const ProviderListResponse(items: [], connectedOnly: false),
        );
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.selectVariant(const SessionVariant(id: "high"));

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() => providerCalls == 2 && cubit.state.agentModelData?.isLoading == false);

      expect(cubit.state.agentModelData?.providers, isEmpty);
      expect(cubit.state.agentModelData?.agentModel, isNull);
      expect(cubit.state.agentModelData?.availableVariants, isEmpty);
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
            ? ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [initialB]))
            : ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA, unavailableB]));
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
        return ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA]));
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
      when(
        pluginRepository.listPlugins,
      ).thenAnswer((_) => Completer<ApiResponse<PluginDiscoverySnapshot>>().future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      final state = cubit.state as NewSessionComposing;

      expect(state.config.availablePlugins, isEmpty);
      expect(state.config.selectedPlugin, isNull);
      expect(state.isComposerDataLoading, isTrue);
      expect(state.config.isPluginDiscoveryInFlight, isTrue);
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
      await _waitUntil(() => cubit.state.phase is NewSessionPhaseDiscoveryError);

      final state = cubit.state as NewSessionComposing;
      expect((state.phase as NewSessionPhaseDiscoveryError).reason, RemoteFailureReason.serverRejected);
      expect(state.config.availablePlugins, isEmpty);
      expect(state.config.selectedPlugin, isNull);
      expect(
        state.config.options,
        isA<NewSessionOptionsLoadingState>().having((options) => options.source, "source", isNull),
      );
      expect(state.isComposerDataLoading, isTrue);
      expect(state.config.isPluginDiscoveryInFlight, isFalse);
      expect(state.availableAgents, isEmpty);
      expect(state.availableProviders, isEmpty);
      expect(state.availableCommands, isEmpty);
      _verifyNoComposerCalls(sessionService);
    });

    test("closed cubit ignores a late discovery completion", () async {
      final discovery = Completer<ApiResponse<PluginDiscoverySnapshot>>();
      when(pluginRepository.listPlugins).thenAnswer((_) => discovery.future);
      final cubit = buildCubit();

      await cubit.close();
      discovery.complete(ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])));
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
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [first, second])),
      );

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);

      final state = cubit.state as NewSessionComposing;
      expect(state.config.availablePlugins.map((plugin) => plugin.id), ["blocked", "selected"]);
      expect(state.config.selectedPlugin, second);
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
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [degraded])),
      );
      when(
        () => sessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(testSession(pluginId: "degraded")));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      await cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "hello"),
        dedicatedWorktree: true,
        command: null,
      );

      verify(() => sessionService.listAgents(projectId: "project-1", pluginId: "degraded")).called(1);
      verify(() => sessionService.listProviders(projectId: "project-1", pluginId: "degraded")).called(1);
      verify(() => sessionService.listCommands(projectId: "project-1", pluginId: "degraded")).called(1);
      verify(
        () => sessionService.createSessionWithMessage(
          attachments: const [],
          projectId: "project-1",
          pluginId: "degraded",
          text: "hello",
          agent: null,
          model: null,
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
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [unavailable, failed])),
      );

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitUntil(() => cubit.state.agentModelData?.isLoading == false);

      final state = cubit.state as NewSessionComposing;
      expect(state.config.availablePlugins, [unavailable, failed]);
      expect(state.config.selectedPlugin, unavailable);
      cubit.selectPlugin(pluginId: "failed");
      cubit.selectPlugin(pluginId: "unknown");
      await cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "blocked"),
        dedicatedWorktree: true,
        command: null,
      );

      expect((cubit.state as NewSessionComposing).config.selectedPlugin, unavailable);
      _verifyNoComposerCalls(sessionService);
      verifyNever(
        () => sessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      );
    });

    test("absent default does not load or create until the user selects a plugin", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginB])),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitUntil(() => cubit.state.agentModelData?.isLoading == false);

      expect(cubit.state.agentModelData?.plugin, isNull);
      await cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "blocked"),
        dedicatedWorktree: true,
        command: null,
      );
      _verifyNoComposerCalls(sessionService);

      cubit.selectPlugin(pluginId: "plugin-b");
      await _waitForComposer(cubit);
      verify(() => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-b")).called(1);
    });

    test("plugin switch clears backend-local composer state synchronously", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA, pluginB])),
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

      final state = cubit.state as NewSessionComposing;
      expect(state.config.selectedPlugin?.id, "plugin-b");
      expect(state.isComposerDataLoading, isTrue);
      expect(state.config.isPluginDiscoveryInFlight, isFalse);
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
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA, pluginB])),
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

      final state = cubit.state as NewSessionComposing;
      expect(state.config.selectedPlugin?.id, "plugin-b");
      expect(state.availableAgents.map((agent) => agent.name), ["agent-b"]);
    });

    test("A-B-A rejects both late original A and B completions", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA, pluginB])),
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

      final state = cubit.state as NewSessionComposing;
      expect(state.config.selectedPlugin?.id, "plugin-a");
      expect(state.availableAgents.map((agent) => agent.name), ["fresh-agent-a"]);
    });

    test("restores selection only from the matching project-plugin key", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: "bridge-a", plugins: [pluginA, pluginB])),
      );
      establishSelectionScope(bridgeId: "bridge-a");
      selectionTracker
        ..recordAgent(projectId: "project-1", pluginId: "plugin-a", agentName: "agent-a")
        ..recordAgent(projectId: "project-1", pluginId: "plugin-b", agentName: "agent-b");
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
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: "bridge-a", plugins: [pluginA, pluginB])),
      );
      establishSelectionScope(bridgeId: "bridge-a");
      selectionTracker
        ..recordAgent(projectId: "project-1", pluginId: "plugin-a", agentName: "agent-a")
        ..recordAgent(projectId: "project-1", pluginId: "plugin-b", agentName: "agent-b");
      when(
        () => sessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(testSession(pluginId: "plugin-a")));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      await cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "hello"),
        dedicatedWorktree: true,
        command: null,
      );

      expect(selectionTracker.read(projectId: "project-1", pluginId: "plugin-a"), isNull);
      expect(selectionTracker.read(projectId: "project-1", pluginId: "plugin-b")?.agentName, "agent-b");
    });

    test("records the submitted plugin against the discovery bridge only when sending", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: "br_test", plugins: [pluginA, pluginB])),
      );
      when(
        () => sessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(testSession(pluginId: "plugin-b")));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.selectPlugin(pluginId: "plugin-b");
      await _waitForComposer(cubit);

      verifyNever(
        () => pluginPreferenceRepository.writePluginId(
          bridgeId: any(named: "bridgeId"),
          pluginId: any(named: "pluginId"),
        ),
      );

      await cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "hello"),
        dedicatedWorktree: true,
        command: null,
      );

      verify(
        () => pluginPreferenceRepository.writePluginId(bridgeId: "br_test", pluginId: "plugin-b"),
      ).called(1);
    });

    test("reconnect to a different bridge identity clears backend-local composer state", () async {
      final command = testCommandInfo();
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        return discoveryCalls == 1
            ? ApiResponse.success(_pluginSnapshot(bridgeId: "br_a", plugins: [pluginA]))
            : ApiResponse.success(_pluginSnapshot(bridgeId: "br_b", plugins: [pluginA]));
      });
      when(
        () => sessionService.listProviders(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) async {
        return discoveryCalls < 2 ? ApiResponse.success(_providerResponse()) : ApiResponse.error(ApiError.generic());
      });
      when(
        () => sessionService.listCommands(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) async {
        return discoveryCalls < 2
            ? ApiResponse.success(CommandListResponse(items: [command]))
            : ApiResponse.error(ApiError.generic());
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.selectVariant(const SessionVariant(id: "high"));
      cubit.stageCommand(command);
      await _waitForComposer(cubit);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() => discoveryCalls == 2 && cubit.state.agentModelData?.isLoading == false);

      final data = cubit.state.agentModelData!;
      expect(data.plugin, pluginA);
      expect(data.stagedCommand, isNull);
      expect(data.commands, isEmpty);
      expect(data.providers, isEmpty);
      expect(data.agentModel, isNull);
    });

    test("reconnect to a different bridge does not restore the prior bridge selection", () async {
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        return ApiResponse.success(
          _pluginSnapshot(bridgeId: discoveryCalls == 1 ? "br_a" : "br_b", plugins: [pluginA]),
        );
      });
      when(
        () => sessionService.listProviders(projectId: "project-1", pluginId: "plugin-a"),
      ).thenAnswer((_) async => ApiResponse.success(_providerResponse()));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      cubit.selectVariant(const SessionVariant(id: "max"));
      expect(cubit.state.agentModelData?.agentModel?.variant, "max");

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() => discoveryCalls == 2 && cubit.state.agentModelData?.isLoading == false);

      expect(cubit.state.agentModelData?.agentModel?.variant, "high");
    });

    test("reconnect during a failed send invalidates affinity and rediscovers afterward", () async {
      final rediscovery = Completer<ApiResponse<PluginDiscoverySnapshot>>();
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) {
        discoveryCalls++;
        return discoveryCalls == 1
            ? Future.value(ApiResponse.success(_pluginSnapshot(bridgeId: "br_a", plugins: [pluginA])))
            : rediscovery.future;
      });
      final createCompleter = Completer<ApiResponse<Session>>();
      when(
        () => sessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) => createCompleter.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);

      final send = cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "hello"),
        dedicatedWorktree: true,
        command: null,
      );
      await _waitUntil(() => cubit.state.phase is NewSessionPhaseSending);
      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      createCompleter.complete(ApiResponse.error(ApiError.generic()));
      await send;

      expect(cubit.canRefreshOptions, isFalse);
      await _waitUntil(() => discoveryCalls == 2);
      rediscovery.complete(ApiResponse.success(_pluginSnapshot(bridgeId: "br_b", plugins: [pluginA])));
      await _waitForComposer(cubit);
      expect(cubit.canRefreshOptions, isTrue);
    });

    test("failed rediscovery does not record under the stale bridge key", () async {
      var discoveryCalls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        if (discoveryCalls == 1) {
          return ApiResponse.success(_pluginSnapshot(bridgeId: "br_test", plugins: [pluginA]));
        }
        return ApiResponse.error(ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null));
      });
      when(
        () => sessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(testSession(pluginId: "plugin-a")));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(connectedStatus);
      await _waitUntil(() {
        final data = cubit.state.agentModelData;
        return cubit.state.phase is NewSessionPhaseDiscoveryError && !(data?.isLoading ?? true);
      });

      clearInteractions(sessionRepository);
      await cubit.refreshOptions();
      verifyNever(
        () => sessionRepository.loadSessionOptions(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      );

      await cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "hello"),
        dedicatedWorktree: true,
        command: null,
      );

      verifyNever(
        () => pluginPreferenceRepository.writePluginId(
          bridgeId: any(named: "bridgeId"),
          pluginId: any(named: "pluginId"),
        ),
      );
      expect(cubit.canCreateSession, isFalse);
      verifyNever(
        () => sessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      );
    });

    test("skips preference recording when discovery carried no bridge identity", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(_pluginSnapshot(bridgeId: null, plugins: [pluginA])),
      );
      when(
        () => sessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(testSession(pluginId: "plugin-a")));

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _waitForComposer(cubit);
      await cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "hello"),
        dedicatedWorktree: true,
        command: null,
      );

      verifyNever(
        () => pluginPreferenceRepository.writePluginId(
          bridgeId: any(named: "bridgeId"),
          pluginId: any(named: "pluginId"),
        ),
      );
    });
  });
}

void _stubEmptyResources(MockSessionRepository sessionService) {
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

void _verifyNoComposerCalls(MockSessionRepository sessionService) {
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

SessionOptionsRepositoryAvailable _optionsCatalog({
  required String agentName,
  required List<ProviderInfo> providers,
  required bool isStale,
}) {
  return SessionOptionsRepositoryAvailable(
    isStale: isStale,
    catalog: SessionOptionsCatalog(
      agents: [_agent(agentName)],
      providers: providers,
      providersConnectedOnly: false,
      commands: const [],
      lastUsedPromptDefaults: null,
    ),
  );
}

/// Lets pending microtasks — a completed request and the work it triggers —
/// finish when the outcome under test is that nothing on screen changed.
Future<void> _settle() async {
  for (var turn = 0; turn < 10; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
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
            variants: ["high", "max"],
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
