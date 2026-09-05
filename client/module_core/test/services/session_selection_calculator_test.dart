import "package:sesori_dart_core/src/services/session_selection_calculator.dart";
import "package:sesori_dart_core/src/testing/test_helpers.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _calculator = SessionSelectionCalculator();

ProviderInfo _provider({
  required String id,
  required Map<String, ProviderModel> models,
  String? defaultModelID,
}) => ProviderInfo(id: id, name: id, models: models, defaultModelID: defaultModelID);

ProviderModel _model({
  required String id,
  required String providerID,
  List<String> variants = const [],
  String? defaultVariant,
  bool isAvailable = true,
}) => ProviderModel(
  id: id,
  providerID: providerID,
  name: id,
  variants: variants,
  defaultVariant: defaultVariant,
  family: null,
  isAvailable: isAvailable,
  releaseDate: null,
);

AgentInfo _agent({
  required String name,
  AgentModel? model,
  AgentMode mode = AgentMode.primary,
  bool hidden = false,
}) => AgentInfo(name: name, description: name, model: model, mode: mode, hidden: hidden);

void main() {
  group("SessionSelectionCalculator selectable agents", () {
    test("hidden agents and sub-agents are not picker entries", () {
      final agents = [
        _agent(name: "build"),
        _agent(name: "secret", hidden: true),
        _agent(name: "helper", mode: AgentMode.subagent),
      ];

      expect(
        _calculator.selectableAgents(agents: agents).map((agent) => agent.name),
        ["build"],
      );
    });
  });

  group("SessionSelectionCalculator availability", () {
    final providers = [
      _provider(
        id: "anthropic",
        models: {
          "opus": _model(id: "opus", providerID: "anthropic", variants: ["high", "low"]),
          "retired": _model(id: "retired", providerID: "anthropic", variants: ["high"], isAvailable: false),
        },
      ),
    ];

    test("a model the backend marks unavailable is treated as absent", () {
      const retired = AgentModel(providerID: "anthropic", modelID: "retired", variant: null);

      expect(_calculator.isModelAvailable(providers: providers, model: retired), isFalse);
      expect(_calculator.availableVariants(providers: providers, model: retired), isEmpty);
    });

    test("an unknown model offers no variants", () {
      const unknown = AgentModel(providerID: "openai", modelID: "gpt", variant: null);

      expect(_calculator.availableVariants(providers: providers, model: unknown), isEmpty);
    });

    test("the backend's no-variant spelling is not a picker entry", () {
      final withNone = [
        _provider(
          id: "anthropic",
          models: {
            "opus": _model(id: "opus", providerID: "anthropic", variants: ["none", "high"]),
          },
        ),
      ];

      expect(
        _calculator
            .availableVariants(
              providers: withNone,
              model: const AgentModel(providerID: "anthropic", modelID: "opus", variant: null),
            )
            .map((variant) => variant.id),
        ["high"],
      );
    });
  });

  group("SessionSelectionCalculator staged command", () {
    test("a command the backend stopped offering is dropped", () {
      expect(
        _calculator.resolveStagedCommand(
          commands: const [],
          staged: testCommandInfo(name: "review"),
        ),
        isNull,
      );
    });

    test("a staged command is re-read from the current catalog", () {
      final current = testCommandInfo(name: "review", template: "/review new");

      final resolved = _calculator.resolveStagedCommand(
        commands: [current],
        staged: testCommandInfo(name: "review", template: "/review old"),
      );

      expect(resolved?.template, "/review new");
    });

    test("nothing staged stays nothing", () {
      expect(
        _calculator.resolveStagedCommand(commands: [testCommandInfo(name: "review")], staged: null),
        isNull,
      );
    });
  });

  group("SessionSelectionCalculator reconcile", () {
    final providers = [
      _provider(
        id: "anthropic",
        models: {
          "opus": _model(id: "opus", providerID: "anthropic", variants: ["high", "low"]),
          "retired": _model(id: "retired", providerID: "anthropic", variants: ["high"], isAvailable: false),
        },
        defaultModelID: "opus",
      ),
    ];
    final agents = [_agent(name: "build"), _agent(name: "plan")];

    test("the first candidate the catalog still offers wins, and nulls are skipped", () {
      final resolved = _calculator.reconcile(
        agents: agents,
        providers: providers,
        agentNameCandidates: [null, "plan"],
        modelCandidates: [
          null,
          const AgentModel(providerID: "anthropic", modelID: "opus", variant: "low"),
        ],
        retainedModel: null,
      );

      expect(resolved.agentName, "plan");
      expect(resolved.model?.modelID, "opus");
      expect(resolved.model?.variant, "low");
      expect(resolved.availableVariants.map((variant) => variant.id), ["high", "low"]);
    });

    test("an unset variant resolves to the model's declared default, not the first listed", () {
      final ranked = [
        _provider(
          id: "anthropic",
          models: {
            "opus": _model(
              id: "opus",
              providerID: "anthropic",
              variants: ["max", "high", "low"],
              defaultVariant: "high",
            ),
          },
          defaultModelID: "opus",
        ),
      ];

      final resolved = _calculator.reconcile(
        agents: agents,
        providers: ranked,
        agentNameCandidates: const [],
        modelCandidates: const [AgentModel(providerID: "anthropic", modelID: "opus", variant: null)],
        retainedModel: null,
      );

      expect(resolved.model?.variant, "high");
      expect(_calculator.defaultVariant(providers: ranked, model: resolved.model), "high");
    });

    test("a withdrawn agent falls back to the first selectable one", () {
      final resolved = _calculator.reconcile(
        agents: agents,
        providers: providers,
        agentNameCandidates: ["deleted"],
        modelCandidates: const [],
        retainedModel: null,
      );

      expect(resolved.agentName, "build");
    });

    test("no selectable agent resolves to null rather than inventing one", () {
      final resolved = _calculator.reconcile(
        agents: [_agent(name: "helper", mode: AgentMode.subagent)],
        providers: providers,
        agentNameCandidates: ["helper"],
        modelCandidates: const [],
        retainedModel: null,
      );

      expect(resolved.agentName, isNull);
    });

    test("an unavailable candidate falls through to the catalog default", () {
      final resolved = _calculator.reconcile(
        agents: agents,
        providers: providers,
        agentNameCandidates: ["build"],
        modelCandidates: [const AgentModel(providerID: "anthropic", modelID: "retired", variant: null)],
        retainedModel: null,
      );

      expect(resolved.model?.modelID, "opus");
    });

    test("a retained model is adopted without catalog validation", () {
      const transcriptModel = AgentModel(providerID: "openai", modelID: "gpt-4.1", variant: null);

      final resolved = _calculator.reconcile(
        agents: agents,
        providers: providers,
        agentNameCandidates: ["build"],
        modelCandidates: const [],
        retainedModel: transcriptModel,
      );

      // A session imported from a terminal keeps running on what it ran on,
      // even when a retained provider cache does not list it.
      expect(resolved.model?.providerID, "openai");
      expect(resolved.model?.modelID, "gpt-4.1");
      expect(resolved.availableVariants, isEmpty);
    });

    test("a surviving candidate outranks the retained model", () {
      final resolved = _calculator.reconcile(
        agents: agents,
        providers: providers,
        agentNameCandidates: ["build"],
        modelCandidates: [const AgentModel(providerID: "anthropic", modelID: "opus", variant: null)],
        retainedModel: const AgentModel(providerID: "openai", modelID: "gpt-4.1", variant: null),
      );

      expect(resolved.model?.modelID, "opus");
    });

    test("the chosen agent's declared model is validated before it is adopted", () {
      final resolved = _calculator.reconcile(
        agents: [
          _agent(
            name: "build",
            model: const AgentModel(providerID: "anthropic", modelID: "retired", variant: null),
          ),
        ],
        providers: providers,
        agentNameCandidates: ["build"],
        modelCandidates: const [],
        retainedModel: null,
      );

      expect(resolved.model?.modelID, "opus");
    });

    test("a withdrawn variant resolves to the model's first, never to unset", () {
      final resolved = _calculator.reconcile(
        agents: agents,
        providers: providers,
        agentNameCandidates: ["build"],
        modelCandidates: [const AgentModel(providerID: "anthropic", modelID: "opus", variant: "gone")],
        retainedModel: null,
      );

      expect(resolved.model?.variant, "high");
    });

    test("variants always describe the model that was chosen", () {
      final resolved = _calculator.reconcile(
        agents: agents,
        providers: providers,
        agentNameCandidates: ["build"],
        modelCandidates: [const AgentModel(providerID: "anthropic", modelID: "retired", variant: null)],
        retainedModel: null,
      );

      expect(resolved.model?.modelID, "opus");
      expect(resolved.availableVariants.map((variant) => variant.id), ["high", "low"]);
    });
  });
}
