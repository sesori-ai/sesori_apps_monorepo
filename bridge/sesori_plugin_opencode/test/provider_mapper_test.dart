import "package:opencode_plugin/src/models/openapi/config_providers_response.g.dart";
import "package:opencode_plugin/src/provider_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginModel;
import "package:test/test.dart";

void main() {
  group("mapProviderResponse", () {
    test("omits OpenCode's API default map so clients use newest-by-date", () {
      final response = ConfigProvidersResponse.fromJson(
        _providersJson(<String, dynamic>{
          "gpt-4.1-mini": _modelJson(
            id: "openai/gpt-4.1-mini",
            name: "GPT-4.1 Mini",
            variants: const <String, dynamic>{},
            family: "gpt-4.1",
            status: "active",
            releaseDate: "2025-04-01",
          ),
        }),
      );

      final mapped = mapProviderResponse(response: response);

      expect(mapped.providers.single.defaultModelID, isNull);
    });

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
      expect(provider.defaultModelID, isNull);
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

    group("releaseDate parsing", () {
      test("parses full YYYY-MM-DD release_date", () {
        final response = ConfigProvidersResponse.fromJson(
          _providersJson(<String, dynamic>{
            "kimi-k2-thinking": _modelJson(
              id: "moonshotai/kimi-k2-thinking",
              name: "Kimi K2 Thinking",
              variants: <String, dynamic>{},
              family: "kimi-thinking",
              status: "active",
              releaseDate: "2025-11-06",
            ),
          }),
        );

        final mapped = mapProviderResponse(response: response);
        final model = mapped.providers.single.models.single;
        expect(model.releaseDate, equals(DateTime(2025, 11, 6)));
      });

      test(
        "parses short YYYY-MM release_date as the first of the month "
        "(regression: kimi-for-coding models were getting null releaseDate)",
        () {
          // Mirrors the live models.dev entry for `kimi-for-coding`:
          //   kimi-k2-thinking -> "2025-11"
          //   k2p5             -> "2026-01"
          //   k2p6             -> "2026-04"
          //
          // Before this fix, `DateTime.tryParse("2025-11")` returned null
          // (Dart only accepts YYYY-MM-DD and full ISO 8601), so every
          // model in the family ended up with a null `releaseDate`. The
          // mobile picker then fell back to iteration order and surfaced
          // "Kimi K2 Thinking" instead of "Kimi K2.6".
          final response = ConfigProvidersResponse.fromJson(
            _providersJson(<String, dynamic>{
              "kimi-k2-thinking": _modelJson(
                id: "kimi-k2-thinking",
                name: "Kimi K2 Thinking",
                variants: <String, dynamic>{},
                family: "kimi-thinking",
                status: "active",
                releaseDate: "2025-11",
              ),
              "k2p5": _modelJson(
                id: "k2p5",
                name: "Kimi K2.5",
                variants: <String, dynamic>{},
                family: "kimi-thinking",
                status: "active",
                releaseDate: "2026-01",
              ),
              "k2p6": _modelJson(
                id: "k2p6",
                name: "Kimi K2.6",
                variants: <String, dynamic>{},
                family: "kimi-thinking",
                status: "active",
                releaseDate: "2026-04",
              ),
            }),
          );

          final mapped = mapProviderResponse(response: response);
          final modelsById = <String, PluginModel>{
            for (final m in mapped.providers.single.models) m.id: m,
          };
          expect(modelsById["kimi-k2-thinking"]!.releaseDate, equals(DateTime(2025, 11, 1)));
          expect(modelsById["k2p5"]!.releaseDate, equals(DateTime(2026, 1, 1)));
          expect(modelsById["k2p6"]!.releaseDate, equals(DateTime(2026, 4, 1)));
        },
      );

      test("leaves releaseDate null when the field is absent", () {
        final response = ConfigProvidersResponse.fromJson(
          _providersJson(<String, dynamic>{
            "gpt-4.1": _modelJson(
              id: "openai/gpt-4.1",
              name: "GPT-4.1",
              variants: <String, dynamic>{},
              family: "gpt-4.1",
              status: "active",
            ),
          }),
        );

        final mapped = mapProviderResponse(response: response);
        expect(mapped.providers.single.models.single.releaseDate, isNull);
      });

      test("leaves releaseDate null when the value is unparseable", () {
        final response = ConfigProvidersResponse.fromJson(
          _providersJson(<String, dynamic>{
            "gpt-4.1": _modelJson(
              id: "openai/gpt-4.1",
              name: "GPT-4.1",
              variants: <String, dynamic>{},
              family: "gpt-4.1",
              status: "active",
              releaseDate: "not-a-date",
            ),
          }),
        );

        final mapped = mapProviderResponse(response: response);
        expect(mapped.providers.single.models.single.releaseDate, isNull);
      });
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
  "api": <String, dynamic>{"id": id, "url": "http://example.com", "npm": "openai"},
  "name": name,
  "family": family,
  "capabilities": <String, dynamic>{
    "temperature": false,
    "reasoning": false,
    "attachment": false,
    "toolcall": false,
    "input": <String, dynamic>{
      "text": true,
      "audio": false,
      "image": false,
      "video": false,
      "pdf": false,
    },
    "output": <String, dynamic>{
      "text": true,
      "audio": false,
      "image": false,
      "video": false,
      "pdf": false,
    },
    "interleaved": false,
  },
  "cost": <String, dynamic>{
    "input": 0,
    "output": 0,
    "cache": <String, dynamic>{"read": 0, "write": 0},
  },
  "limit": <String, dynamic>{"context": 0, "output": 0},
  "status": status,
  "options": <String, dynamic>{},
  "headers": <String, dynamic>{},
  "release_date": releaseDate,
  "variants": variants,
};
