import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
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

void main() {
  group("NewSessionCubit plugin selection", () {
    late MockSessionService sessionService;
    late MockPluginRepository pluginRepository;
    late NewSessionSelectionTracker selectionTracker;

    setUp(() {
      sessionService = MockSessionService();
      pluginRepository = MockPluginRepository();
      selectionTracker = NewSessionSelectionTracker();
      _stubEmptyResources(sessionService);
    });

    NewSessionCubit buildCubit() => NewSessionCubit(
      sessionService: sessionService,
      pluginRepository: pluginRepository,
      selectionTracker: selectionTracker,
      projectId: "project-1",
    );

    test("initial state has no synthetic selection and waits for discovery", () {
      when(pluginRepository.listPlugins).thenAnswer((_) => Completer<ApiResponse<PluginListResponse>>().future);

      final cubit = buildCubit();
      addTearDown(cubit.close);
      final state = cubit.state as NewSessionIdle;

      expect(state.availablePlugins, isEmpty);
      expect(state.selectedPlugin, isNull);
      expect(state.isComposerDataLoading, isTrue);
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
