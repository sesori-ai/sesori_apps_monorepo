import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/foundation/models/session_options/session_options_request_mode.dart";
import "package:sesori_dart_core/src/repositories/models/session_options_repository_result.dart";
import "package:sesori_dart_core/src/services/models/new_session_options_source.dart";
import "package:sesori_dart_core/src/services/models/new_session_selection_intent.dart";
import "package:sesori_dart_core/src/services/new_session_options_service.dart";
import "package:sesori_dart_core/src/utils/model_filter/default_model_selector.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("NewSessionOptionsService", () {
    late MockSessionRepository repository;
    late NewSessionOptionsService service;

    setUp(() {
      repository = MockSessionRepository();
      service = NewSessionOptionsService(
        sessionRepository: repository,
        defaultModelSelector: const DefaultModelSelector(),
      );
    });

    test("legacy source is unsupported without repository calls", () async {
      final result = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.legacy,
        mode: NewSessionOptionsLoadMode.dynamicLoad,
        restoredSelection: null,
        previousOptions: null,
      );

      expect(result, isA<NewSessionOptionsUnsupported>());
      verifyNever(
        () => repository.loadSessionOptions(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          mode: any(named: "mode"),
        ),
      );
      verifyNever(
        () => repository.loadLegacySessionOptions(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      );
    });

    test("explicit legacy refresh loads the repository catalog", () async {
      final catalog = SessionOptionsCatalog(
        agents: [_agent(name: "build")],
        providers: _providers().items,
        providersConnectedOnly: false,
        commands: [_command(name: "review")],
        lastUsedPromptDefaults: null,
      );
      when(
        () => repository.loadLegacySessionOptions(projectId: "project-1", pluginId: "plugin-1"),
      ).thenAnswer((_) async => LegacySessionOptionsRepositoryAvailable(catalog: catalog));

      final result = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.legacy,
        mode: NewSessionOptionsLoadMode.forcedRefresh,
        restoredSelection: null,
        previousOptions: null,
      );

      expect(
        result,
        isA<NewSessionOptionsLoaded>()
            .having((value) => value.source, "source", NewSessionOptionsSource.legacy)
            .having((value) => value.options.agents.single.name, "agent", "build")
            .having((value) => value.options.commands.single.name, "command", "review"),
      );
      verify(
        () => repository.loadLegacySessionOptions(projectId: "project-1", pluginId: "plugin-1"),
      ).called(1);
      verifyNever(
        () => repository.loadSessionOptions(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          mode: any(named: "mode"),
        ),
      );
    });

    test("partial legacy refresh preserves the available catalog", () async {
      final error = ApiError.generic();
      final catalog = SessionOptionsCatalog(
        agents: const [],
        providers: _providers().items,
        providersConnectedOnly: false,
        commands: [_command(name: "review")],
        lastUsedPromptDefaults: null,
      );
      when(
        () => repository.loadLegacySessionOptions(projectId: "project-1", pluginId: "plugin-1"),
      ).thenAnswer(
        (_) async => LegacySessionOptionsRepositoryPartial(
          catalog: catalog,
          errors: [LegacySessionOptionError(source: LegacySessionOptionSource.agents, error: error)],
        ),
      );

      final result = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.legacy,
        mode: NewSessionOptionsLoadMode.forcedRefresh,
        restoredSelection: null,
        previousOptions: null,
      );

      expect(
        result,
        isA<NewSessionOptionsLoaded>()
            .having((value) => value.source, "source", NewSessionOptionsSource.legacy)
            .having((value) => value.options.providers, "providers", catalog.providers)
            .having((value) => value.options.commands.single.name, "command", "review"),
      );
    });

    test("partial legacy refresh retains prior data only for failed sources", () async {
      final previousProviders = _providers().items;
      final previous = NewSessionOptionsData(
        agents: [_agent(name: "old-agent")],
        providers: previousProviders,
        commands: [_command(name: "old-command")],
        selectedAgent: "old-agent",
        selectedAgentModel: const AgentModel(providerID: "provider-a", modelID: "model-a", variant: null),
        stagedCommand: null,
        availableVariants: const [],
      );
      final catalog = SessionOptionsCatalog(
        agents: [_agent(name: "new-agent")],
        providers: const [],
        providersConnectedOnly: false,
        commands: [_command(name: "new-command")],
        lastUsedPromptDefaults: null,
      );
      when(
        () => repository.loadLegacySessionOptions(projectId: "project-1", pluginId: "plugin-1"),
      ).thenAnswer(
        (_) async => LegacySessionOptionsRepositoryPartial(
          catalog: catalog,
          errors: [
            LegacySessionOptionError(
              source: LegacySessionOptionSource.providers,
              error: ApiError.generic(),
            ),
          ],
        ),
      );

      final result =
          await service.load(
                projectId: "project-1",
                pluginId: "plugin-1",
                source: NewSessionOptionsSource.legacy,
                mode: NewSessionOptionsLoadMode.forcedRefresh,
                restoredSelection: null,
                previousOptions: previous,
              )
              as NewSessionOptionsLoaded;

      expect(result.options.agents.single.name, "new-agent");
      expect(result.options.providers, previousProviders);
      expect(result.options.commands.single.name, "new-command");
    });

    test("legacy repository failure remains a legacy load failure", () async {
      final error = ApiError.generic();
      when(
        () => repository.loadLegacySessionOptions(projectId: "project-1", pluginId: "plugin-1"),
      ).thenAnswer(
        (_) async => LegacySessionOptionsRepositoryFailure(
          errors: [LegacySessionOptionError(source: LegacySessionOptionSource.agents, error: error)],
        ),
      );

      final result = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.legacy,
        mode: NewSessionOptionsLoadMode.forcedRefresh,
        restoredSelection: null,
        previousOptions: null,
      );

      expect(
        result,
        isA<NewSessionOptionsFailureUnavailable>()
            .having((value) => value.error, "error", error)
            .having((value) => value.source, "source", NewSessionOptionsSource.legacy),
      );
      verifyNever(
        () => repository.loadSessionOptions(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          mode: any(named: "mode"),
        ),
      );
    });

    test("aggregate failure never falls back to the legacy repository", () async {
      final error = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null);
      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).thenAnswer((_) async => SessionOptionsRepositoryProjectNotFound(error: error));

      final result = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.aggregate,
        mode: NewSessionOptionsLoadMode.dynamicLoad,
        restoredSelection: null,
        previousOptions: null,
      );

      expect(
        result,
        isA<NewSessionOptionsFailureUnavailable>()
            .having((value) => value.error, "error", error)
            .having((value) => value.source, "source", NewSessionOptionsSource.aggregate),
      );
      verifyNever(
        () => repository.loadLegacySessionOptions(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      );
    });

    test("filters agents and restores selectable agent, model, and ordered variants", () async {
      final catalog = SessionOptionsCatalog(
        agents: [
          _agent(name: "hidden", hidden: true),
          _agent(name: "subtask", mode: AgentMode.subagent),
          _agent(name: "build"),
          _agent(name: "review"),
        ],
        providers: _providers().items,
        providersConnectedOnly: false,
        commands: [_command(name: "review")],
        lastUsedPromptDefaults: null,
      );
      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).thenAnswer((_) async => SessionOptionsRepositoryAvailable(catalog: catalog, isStale: false));

      final result =
          await service.load(
                projectId: "project-1",
                pluginId: "plugin-1",
                source: NewSessionOptionsSource.aggregate,
                mode: NewSessionOptionsLoadMode.dynamicLoad,
                restoredSelection: const NewSessionSelectionIntent(
                  agentName: "review",
                  model: NewSessionModelIntent(providerId: "provider-a", modelId: "model-a"),
                  variant: NewSessionVariantIntent(id: "low"),
                ),
                previousOptions: null,
              )
              as NewSessionOptionsLoaded;

      expect(result.options.agents.map((agent) => agent.name), ["build", "review"]);
      expect(result.options.selectedAgent, "review");
      expect(result.options.selectedAgentModel?.modelID, "model-a");
      expect(result.options.selectedAgentModel?.variant, "low");
      expect(result.options.availableVariants.map((variant) => variant.id), ["high", "low"]);
      expect(result.source, NewSessionOptionsSource.aggregate);
    });

    test("restores last successful creation defaults with deliberate dimensions taking precedence", () async {
      final catalog = SessionOptionsCatalog(
        agents: [_agent(name: "build"), _agent(name: "review")],
        providers: _providers().items,
        providersConnectedOnly: false,
        commands: const [],
        lastUsedPromptDefaults: const SessionPromptDefaults(
          agent: "review",
          model: AgentModel(providerID: "provider-a", modelID: "model-a", variant: "low"),
        ),
      );
      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).thenAnswer((_) async => SessionOptionsRepositoryAvailable(catalog: catalog, isStale: false));

      final result =
          await service.load(
                projectId: "project-1",
                pluginId: "plugin-1",
                source: NewSessionOptionsSource.aggregate,
                mode: NewSessionOptionsLoadMode.dynamicLoad,
                restoredSelection: const NewSessionSelectionIntent(
                  agentName: "build",
                  model: null,
                  variant: null,
                ),
                previousOptions: null,
              )
              as NewSessionOptionsLoaded;

      expect(result.options.selectedAgent, "build");
      expect(result.options.selectedAgentModel?.modelID, "model-a");
      expect(result.options.selectedAgentModel?.variant, "low");
    });

    test("unavailable remembered defaults fall back by provider order", () async {
      final catalog = SessionOptionsCatalog(
        agents: [_agent(name: "build")],
        providers: _providers().items,
        providersConnectedOnly: false,
        commands: const [],
        lastUsedPromptDefaults: const SessionPromptDefaults(
          agent: "missing",
          model: AgentModel(providerID: "provider-a", modelID: "unavailable", variant: "stale"),
        ),
      );
      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).thenAnswer((_) async => SessionOptionsRepositoryAvailable(catalog: catalog, isStale: false));

      final result =
          await service.load(
                projectId: "project-1",
                pluginId: "plugin-1",
                source: NewSessionOptionsSource.aggregate,
                mode: NewSessionOptionsLoadMode.dynamicLoad,
                restoredSelection: null,
                previousOptions: null,
              )
              as NewSessionOptionsLoaded;

      expect(result.options.selectedAgent, "build");
      expect(result.options.selectedAgentModel?.providerID, "provider-a");
      expect(result.options.selectedAgentModel?.modelID, "model-a");
      expect(result.options.selectedAgentModel?.variant, "high");
    });

    test("unavailable restored and agent models fall back by provider order", () async {
      final catalog = SessionOptionsCatalog(
        agents: [
          _agent(
            name: "build",
            model: const AgentModel(providerID: "provider-a", modelID: "unavailable", variant: null),
          ),
        ],
        providers: _providers().items,
        providersConnectedOnly: false,
        commands: const [],
        lastUsedPromptDefaults: null,
      );
      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).thenAnswer((_) async => SessionOptionsRepositoryAvailable(catalog: catalog, isStale: false));

      final result =
          await service.load(
                projectId: "project-1",
                pluginId: "plugin-1",
                source: NewSessionOptionsSource.aggregate,
                mode: NewSessionOptionsLoadMode.dynamicLoad,
                restoredSelection: const NewSessionSelectionIntent(
                  agentName: "missing",
                  model: NewSessionModelIntent(providerId: "provider-a", modelId: "unavailable"),
                  variant: NewSessionVariantIntent(id: "stale"),
                ),
                previousOptions: null,
              )
              as NewSessionOptionsLoaded;

      expect(result.options.selectedAgent, "build");
      expect(result.options.selectedAgentModel?.providerID, "provider-a");
      expect(result.options.selectedAgentModel?.modelID, "model-a");
    });

    test("replaces stale variants and revalidates a staged command by name", () async {
      final priorCommand = _command(name: "review", description: "old");
      final refreshedCommand = _command(name: "review", description: "new");
      final previous = NewSessionOptionsData(
        agents: const [],
        providers: const [],
        commands: [priorCommand],
        selectedAgent: null,
        selectedAgentModel: null,
        stagedCommand: priorCommand,
        availableVariants: const [],
      );
      final catalog = SessionOptionsCatalog(
        agents: [_agent(name: "build")],
        providers: _providers().items,
        providersConnectedOnly: false,
        commands: [refreshedCommand],
        lastUsedPromptDefaults: null,
      );
      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).thenAnswer((_) async => SessionOptionsRepositoryAvailable(catalog: catalog, isStale: false));

      final result =
          await service.load(
                projectId: "project-1",
                pluginId: "plugin-1",
                source: NewSessionOptionsSource.aggregate,
                mode: NewSessionOptionsLoadMode.dynamicLoad,
                restoredSelection: const NewSessionSelectionIntent(
                  agentName: "build",
                  model: NewSessionModelIntent(providerId: "provider-a", modelId: "model-a"),
                  variant: NewSessionVariantIntent(id: "removed"),
                ),
                previousOptions: previous,
              )
              as NewSessionOptionsLoaded;

      expect(result.options.selectedAgentModel?.variant, "high");
      expect(identical(result.options.stagedCommand, refreshedCommand), isTrue);
    });

    test("maps cache and refresh outcomes without retaining invalid options", () async {
      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).thenAnswer((_) async => const SessionOptionsRepositoryCacheUnavailable());
      final unavailable = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.aggregate,
        mode: NewSessionOptionsLoadMode.dynamicLoad,
        restoredSelection: null,
        previousOptions: null,
      );
      expect(unavailable, isA<NewSessionOptionsUnavailable>());

      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).thenAnswer((_) async => const SessionOptionsRepositoryRefreshFailedUnavailable());
      final dynamicFailure = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.aggregate,
        mode: NewSessionOptionsLoadMode.dynamicLoad,
        restoredSelection: null,
        previousOptions: null,
      );
      expect(dynamicFailure, isA<NewSessionOptionsLoadFailureUnavailable>());

      const previous = NewSessionOptionsData(
        agents: [],
        providers: [],
        commands: [],
        selectedAgent: null,
        selectedAgentModel: null,
        stagedCommand: null,
        availableVariants: [],
      );
      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => SessionOptionsRepositoryFailure(error: ApiError.generic()));
      final transientFailure = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.aggregate,
        mode: NewSessionOptionsLoadMode.forcedRefresh,
        restoredSelection: null,
        previousOptions: previous,
      );
      expect(
        transientFailure,
        isA<NewSessionOptionsFailureRetained>()
            .having((value) => value.options, "retained options", previous)
            .having((value) => value.source, "source", NewSessionOptionsSource.aggregate),
      );

      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => const SessionOptionsRepositoryRefreshFailedRetained());
      final retained = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.aggregate,
        mode: NewSessionOptionsLoadMode.forcedRefresh,
        restoredSelection: null,
        previousOptions: previous,
      );
      expect(
        retained,
        isA<NewSessionOptionsFailureRetained>().having(
          (value) => identical(value.options, previous),
          "retained options",
          isTrue,
        ),
      );

      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => const SessionOptionsRepositoryRefreshFailedUnavailable());
      final cleared = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.aggregate,
        mode: NewSessionOptionsLoadMode.forcedRefresh,
        restoredSelection: null,
        previousOptions: previous,
      );
      expect(cleared, isA<NewSessionOptionsRefreshFailureUnavailable>());
    });
  });
}

ProviderListResponse _providers() => ProviderListResponse(
  connectedOnly: false,
  items: [
    ProviderInfo(
      id: "provider-a",
      name: "Provider A",
      defaultModelID: "model-a",
      models: {
        "model-a": _model(id: "model-a", providerId: "provider-a", variants: const ["none", "high", "low"]),
        "unavailable": _model(id: "unavailable", providerId: "provider-a", isAvailable: false),
      },
    ),
    ProviderInfo(
      id: "provider-b",
      name: "Provider B",
      defaultModelID: "model-b",
      models: {"model-b": _model(id: "model-b", providerId: "provider-b")},
    ),
  ],
);

ProviderModel _model({
  required String id,
  required String providerId,
  List<String> variants = const [],
  bool isAvailable = true,
}) => ProviderModel(
  id: id,
  providerID: providerId,
  name: id,
  variants: variants,
  family: null,
  isAvailable: isAvailable,
  releaseDate: null,
);

AgentInfo _agent({
  required String name,
  AgentModel? model,
  AgentMode mode = AgentMode.primary,
  bool hidden = false,
}) => AgentInfo(
  name: name,
  description: null,
  model: model,
  mode: mode,
  hidden: hidden,
);

CommandInfo _command({required String name, String? description}) => CommandInfo(
  name: name,
  template: "/$name",
  hints: const [],
  description: description,
  agent: null,
  model: null,
  provider: null,
  source: CommandSource.command,
  subtask: false,
);
