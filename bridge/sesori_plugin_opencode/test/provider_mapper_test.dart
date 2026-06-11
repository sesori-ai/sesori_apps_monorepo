import "package:opencode_plugin/src/models/openapi/config_providers_response.g.dart";
import "package:opencode_plugin/src/provider_mapper.dart";
import "package:test/test.dart";

void main() {
  group("mapProviderResponse", () {
    test("preserves synthetic model IDs and treats alpha/beta statuses as available", () {
      final response = ConfigProvidersResponse.fromJson(
        _providersJson(<String, dynamic>{
          "alpha-key": _modelJson(
            id: "openai/gpt-4.1-alpha",
            name: "GPT-4.1 Alpha",
            variants: <String, dynamic>{"low": <String, dynamic>{}, "high": <String, dynamic>{}},
            family: "gpt-4.1",
            status: "alpha",
          ),
          "beta-key": _modelJson(
            id: "openai/gpt-4.1-mini",
            name: "GPT-4.1 Mini",
            variants: <String, dynamic>{"medium": <String, dynamic>{}},
            family: "gpt-4.1",
            status: "beta",
            releaseDate: "2025-04-01",
          ),
        }),
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
      final response = ConfigProvidersResponse.fromJson(
        _providersJson(<String, dynamic>{
          "synthetic-key": _modelJson(
            id: "openai/gpt-4.1-mini",
            name: "GPT-4.1 Mini",
            variants: const <String, dynamic>{},
            family: "gpt-4.1",
            status: "preview",
          ),
        }),
      );

      final mapped = mapProviderResponse(response: response);

      expect(mapped.providers, hasLength(1));
      expect(mapped.providers.single.models.single.isAvailable, isTrue);
    });

    test("filters disabled variants from config provider response", () {
      final response = ConfigProvidersResponse.fromJson(
        _providersJson(<String, dynamic>{
          "gpt-4.1": _modelJson(
            id: "openai/gpt-4.1",
            name: "GPT-4.1",
            variants: <String, dynamic>{
              "low": {"disabled": false},
              "medium": {"disabled": true},
              "high": <String, dynamic>{},
            },
            family: "gpt-4.1",
            status: "active",
          ),
        }),
      );

      final mapped = mapProviderResponse(response: response);

      expect(mapped.providers.single.models.single.variants, equals(["low", "high"]));
    });
  });
}

Map<String, dynamic> _providersJson(Map<String, dynamic> models) => <String, dynamic>{
  "providers": [
    {
      "id": "openai",
      "name": "OpenAI",
      "source": "custom",
      "env": <String>[],
      "options": <String, dynamic>{},
      "models": models,
    },
  ],
  "default": {"openai": "openai/gpt-4.1-mini"},
};

Map<String, dynamic> _modelJson({
  required String id,
  required String name,
  required Map<String, dynamic> variants,
  required String family,
  required String status,
  String releaseDate = "",
}) => <String, dynamic>{
  "id": id,
  "providerID": "openai",
  "api": <String, dynamic>{"url": "http://example.com"},
  "name": name,
  "family": family,
  "capabilities": <String, dynamic>{},
  "cost": <String, dynamic>{"input": 0, "output": 0, "cache_read": 0, "cache_write": 0},
  "limit": <String, dynamic>{"context": 0, "output": 0},
  "status": status,
  "options": <String, dynamic>{},
  "headers": <String, dynamic>{},
  "release_date": releaseDate,
  "variants": variants,
};
