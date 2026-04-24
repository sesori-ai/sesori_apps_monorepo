import "package:sesori_dart_core/src/services/agent_variant_options_builder.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("AgentVariantOptionsBuilder", () {
    const builder = AgentVariantOptionsBuilder();

    test("returns empty list when agentModel is null", () {
      final result = builder.build(agentModel: null);
      expect(result, isEmpty);
    });

    test("returns variant from agentModel", () {
      final result = builder.build(
        agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "xhigh"),
      );
      expect(result, const [SessionVariant(id: "xhigh")]);
    });

    test("returns empty list when variant is none", () {
      final result = builder.build(
        agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "none"),
      );
      expect(result, isEmpty);
    });

    test("returns empty list when variant is null", () {
      final result = builder.build(
        agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
      );
      expect(result, isEmpty);
    });
  });
}
