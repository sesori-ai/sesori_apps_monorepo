import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/repositories/models/session_options_repository_result.dart";
import "package:sesori_dart_core/src/services/models/new_session_options_source.dart";
import "package:sesori_dart_core/src/services/models/new_session_selection_intent.dart";
import "package:sesori_dart_core/src/services/new_session_options_service.dart";
import "package:sesori_dart_core/src/utils/model_filter/default_model_selector.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
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
        refresh: false,
        restoredSelection: null,
        previousOptions: null,
      );

      expect(result, isA<NewSessionOptionsUnsupported>());
      verifyNever(
        () => repository.loadSessionOptions(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          refresh: any(named: "refresh"),
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
        commands: [_command(name: "review")],
      );
      when(
        () => repository.loadLegacySessionOptions(projectId: "project-1", pluginId: "plugin-1"),
      ).thenAnswer((_) async => LegacySessionOptionsRepositoryAvailable(catalog: catalog));

      final result = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.legacy,
        refresh: true,
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
          refresh: any(named: "refresh"),
        ),
      );
    });

    test("legacy repository failure remains a legacy load failure", () async {
      final error = ApiError.generic();
      when(
        () => repository.loadLegacySessionOptions(projectId: "project-1", pluginId: "plugin-1"),
      ).thenAnswer((_) async => LegacySessionOptionsRepositoryFailure(error: error));

      final result = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.legacy,
        refresh: true,
        restoredSelection: null,
        previousOptions: null,
      );

      expect(
        result,
        isA<NewSessionOptionsLoadFailure>()
            .having((value) => value.error, "error", error)
            .having((value) => value.source, "source", NewSessionOptionsSource.legacy),
      );
      verifyNever(
        () => repository.loadSessionOptions(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          refresh: any(named: "refresh"),
        ),
      );
    });

    test("aggregate failure never falls back to the legacy repository", () async {
      final error = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null);
      when(
        () => repository.loadSessionOptions(projectId: "project-1", pluginId: "plugin-1", refresh: false),
      ).thenAnswer((_) async => SessionOptionsRepositoryProjectNotFound(error: error));

      final result = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.aggregate,
        refresh: false,
        restoredSelection: null,
        previousOptions: null,
      );

      expect(
        result,
        isA<NewSessionOptionsProjectNotFound>()
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
        commands: [_command(name: "review")],
      );
      when(
        () => repository.loadSessionOptions(projectId: "project-1", pluginId: "plugin-1", refresh: false),
      ).thenAnswer((_) async => SessionOptionsRepositoryAvailable(catalog: catalog));

      final result =
          await service.load(
                projectId: "project-1",
                pluginId: "plugin-1",
                source: NewSessionOptionsSource.aggregate,
                refresh: false,
                restoredSelection: const NewSessionSelectionIntent(
                  agentName: "review",
                  model: NewSessionModelIntent(providerId: "provider-a", modelId: "model-a"),
                  variant: NewSessionNamedVariantIntent(id: "low"),
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

    test("unavailable restored and agent models fall back by provider order", () async {
      final catalog = SessionOptionsCatalog(
        agents: [
          _agent(
            name: "build",
            model: const AgentModel(providerID: "provider-a", modelID: "unavailable", variant: null),
          ),
        ],
        providers: _providers().items,
        commands: const [],
      );
      when(
        () => repository.loadSessionOptions(projectId: "project-1", pluginId: "plugin-1", refresh: false),
      ).thenAnswer((_) async => SessionOptionsRepositoryAvailable(catalog: catalog));

      final result =
          await service.load(
                projectId: "project-1",
                pluginId: "plugin-1",
                source: NewSessionOptionsSource.aggregate,
                refresh: false,
                restoredSelection: const NewSessionSelectionIntent(
                  agentName: "missing",
                  model: NewSessionModelIntent(providerId: "provider-a", modelId: "unavailable"),
                  variant: NewSessionDefaultVariantIntent(),
                ),
                previousOptions: null,
              )
              as NewSessionOptionsLoaded;

      expect(result.options.selectedAgent, "build");
      expect(result.options.selectedAgentModel?.providerID, "provider-a");
      expect(result.options.selectedAgentModel?.modelID, "model-a");
    });

    test("drops stale variants and revalidates a staged command by name", () async {
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
        commands: [refreshedCommand],
      );
      when(
        () => repository.loadSessionOptions(projectId: "project-1", pluginId: "plugin-1", refresh: false),
      ).thenAnswer((_) async => SessionOptionsRepositoryAvailable(catalog: catalog));

      final result =
          await service.load(
                projectId: "project-1",
                pluginId: "plugin-1",
                source: NewSessionOptionsSource.aggregate,
                refresh: false,
                restoredSelection: const NewSessionSelectionIntent(
                  agentName: "build",
                  model: NewSessionModelIntent(providerId: "provider-a", modelId: "model-a"),
                  variant: NewSessionNamedVariantIntent(id: "removed"),
                ),
                previousOptions: previous,
              )
              as NewSessionOptionsLoaded;

      expect(result.options.selectedAgentModel?.variant, isNull);
      expect(identical(result.options.stagedCommand, refreshedCommand), isTrue);
    });

    test("maps cache and refresh outcomes without retaining invalid options", () async {
      when(
        () => repository.loadSessionOptions(projectId: "project-1", pluginId: "plugin-1", refresh: false),
      ).thenAnswer((_) async => const SessionOptionsRepositoryCacheUnavailable());
      final unavailable = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.aggregate,
        refresh: false,
        restoredSelection: null,
        previousOptions: null,
      );
      expect(unavailable, isA<NewSessionOptionsUnavailable>());

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
        () => repository.loadSessionOptions(projectId: "project-1", pluginId: "plugin-1", refresh: true),
      ).thenAnswer((_) async => const SessionOptionsRepositoryRefreshFailedRetained());
      final retained = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.aggregate,
        refresh: true,
        restoredSelection: null,
        previousOptions: previous,
      );
      expect(
        retained,
        isA<NewSessionOptionsRefreshFailureRetained>().having(
          (value) => identical(value.options, previous),
          "retained options",
          isTrue,
        ),
      );

      when(
        () => repository.loadSessionOptions(projectId: "project-1", pluginId: "plugin-1", refresh: true),
      ).thenAnswer((_) async => const SessionOptionsRepositoryRefreshFailedUnavailable());
      final cleared = await service.load(
        projectId: "project-1",
        pluginId: "plugin-1",
        source: NewSessionOptionsSource.aggregate,
        refresh: true,
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
