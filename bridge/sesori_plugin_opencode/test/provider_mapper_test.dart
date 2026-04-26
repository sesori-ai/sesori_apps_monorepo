import "package:opencode_plugin/src/models/provider_info.dart";
import "package:opencode_plugin/src/provider_mapper.dart";
import "package:test/test.dart";

void main() {
  group("mapProviderResponse", () {
    test("preserves synthetic model IDs and treats alpha/beta statuses as available", () {
      const response = ProviderListResponse(
        providers: [
          ProviderInfo(
            id: "openai",
            name: "OpenAI",
            models: {
              "alpha-key": ProviderModel(
                id: "openai/gpt-4.1-alpha",
                providerID: "openai",
                name: "GPT-4.1 Alpha",
                variants: ["low", "high"],
                family: "gpt-4.1",
                status: "alpha",
              ),
              "beta-key": ProviderModel(
                id: "openai/gpt-4.1-mini",
                providerID: "openai",
                name: "GPT-4.1 Mini",
                variants: ["medium"],
                family: "gpt-4.1",
                status: "beta",
                releaseDate: "2025-04-01",
              ),
            },
          ),
        ],
        defaults: {"openai": "openai/gpt-4.1-mini"},
        connected: ["openai"],
      );

      final mapped = mapProviderResponse(response: response);

      expect(mapped.providers, hasLength(1));
      final provider = mapped.providers.first;
      expect(provider.id, equals("openai"));
      expect(provider.defaultModelID, equals("openai/gpt-4.1-mini"));
      expect(provider.models, hasLength(2));

      final alphaModel = provider.models.firstWhere((model) => model.id == "openai/gpt-4.1-alpha");
      expect(alphaModel.isAvailable, isTrue);
      expect(alphaModel.variants, equals(["low", "high"]));

      final betaModel = provider.models.firstWhere((model) => model.id == "openai/gpt-4.1-mini");
      expect(betaModel.isAvailable, isTrue);
      expect(betaModel.variants, equals(["medium"]));
      expect(betaModel.releaseDate, equals(DateTime(2025, 4, 1)));
    });

    test("treats still-unknown statuses as available", () {
      const response = ProviderListResponse(
        providers: [
          ProviderInfo(
            id: "openai",
            name: "OpenAI",
            models: {
              "synthetic-key": ProviderModel(
                id: "openai/gpt-4.1-mini",
                providerID: "openai",
                name: "GPT-4.1 Mini",
                variants: [],
                family: "gpt-4.1",
                status: "preview",
              ),
            },
          ),
        ],
        defaults: {"openai": "openai/gpt-4.1-mini"},
        connected: ["openai"],
      );

      final mapped = mapProviderResponse(response: response);

      expect(mapped.providers, hasLength(1));
      expect(mapped.providers.single.models.single.isAvailable, isTrue);
    });

    test("filters disabled variants from config provider response", () {
      final response = ProviderListResponse.fromJson({
        "providers": [
          {
            "id": "openai",
            "name": "OpenAI",
            "models": {
              "gpt-4.1": {
                "id": "openai/gpt-4.1",
                "providerID": "openai",
                "name": "GPT-4.1",
                "variants": {
                  "low": {"disabled": false},
                  "medium": {"disabled": true},
                  "high": <String, dynamic>{},
                },
              },
            },
          },
        ],
        "default": {"openai": "openai/gpt-4.1"},
      });

      final mapped = mapProviderResponse(response: response);

      expect(mapped.providers.single.models.single.variants, equals(["low", "high"]));
    });
  });
}
