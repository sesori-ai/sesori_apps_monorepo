import "package:opencode_plugin/src/models/provider_info.dart";
import "package:opencode_plugin/src/provider_mapper.dart";
import "package:test/test.dart";

void main() {
  group("mapProviderResponse", () {
    test("preserves synthetic model IDs and treats unknown statuses as available", () {
      const response = ProviderListResponse(
        all: [
          ProviderInfo(
            id: "openai",
            name: "OpenAI",
            models: {
              "synthetic-key": ProviderModel(
                id: "openai/gpt-4.1-mini",
                providerID: "openai",
                name: "GPT-4.1 Mini",
                family: "gpt-4.1",
                status: "preview",
                releaseDate: "2025-04-01",
              ),
            },
          ),
        ],
        defaults: {"openai": "openai/gpt-4.1-mini"},
        connected: ["openai"],
      );

      final mapped = mapProviderResponse(response: response, connectedOnly: false);

      expect(mapped.providers, hasLength(1));
      final provider = mapped.providers.first;
      expect(provider.id, equals("openai"));
      expect(provider.defaultModelID, equals("openai/gpt-4.1-mini"));
      expect(provider.models, hasLength(1));

      final model = provider.models.first;
      expect(model.id, equals("openai/gpt-4.1-mini"));
      expect(model.isAvailable, isTrue);
      expect(model.releaseDate, equals(DateTime(2025, 4, 1)));
    });
  });
}
