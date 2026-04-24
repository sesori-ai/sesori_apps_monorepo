import "package:sesori_dart_core/src/services/agent_variant_options_builder.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("AgentVariantOptionsBuilder", () {
    const builder = AgentVariantOptionsBuilder();

    test("returns empty list when agentName is null", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: null,
            variant: "xhigh",
            mode: AgentMode.primary,
          ),
        ],
        agentName: null,
        providerID: null,
        modelID: null,
      );
      expect(result, isEmpty);
    });

    test("returns variant matching by name only when no model is provided", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: null,
            variant: "xhigh",
            mode: AgentMode.primary,
          ),
        ],
        agentName: "build",
        providerID: null,
        modelID: null,
      );
      expect(result, const [SessionVariant(id: "xhigh")]);
    });

    test("returns variant matching by name and model when model is provided", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: AgentModel(providerID: "openai", modelID: "gpt-4"),
            variant: "fast",
            mode: AgentMode.primary,
          ),
          AgentInfo(
            name: "build",
            description: "Build",
            model: AgentModel(providerID: "anthropic", modelID: "claude-3"),
            variant: "deep",
            mode: AgentMode.primary,
          ),
        ],
        agentName: "build",
        providerID: "anthropic",
        modelID: "claude-3",
      );
      expect(result, const [SessionVariant(id: "deep")]);
    });

    test("returns empty list when variant is none", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: null,
            variant: "none",
            mode: AgentMode.primary,
          ),
        ],
        agentName: "build",
        providerID: null,
        modelID: null,
      );
      expect(result, isEmpty);
    });

    test("returns empty list when variant is null", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: null,
            variant: null,
            mode: AgentMode.primary,
          ),
        ],
        agentName: "build",
        providerID: null,
        modelID: null,
      );
      expect(result, isEmpty);
    });

    test("falls back to name-only match when no model match exists", () {
      final result = builder.build(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: null,
            variant: "default",
            mode: AgentMode.primary,
          ),
        ],
        agentName: "build",
        providerID: "openai",
        modelID: "gpt-4",
      );
      expect(result, const [SessionVariant(id: "default")]);
    });
  });
}
