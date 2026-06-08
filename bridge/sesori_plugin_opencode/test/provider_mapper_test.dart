import "package:opencode_plugin/src/models/provider_info.dart";
import "package:opencode_plugin/src/provider_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginModel;
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

    group("releaseDate parsing", () {
      test("parses full YYYY-MM-DD release_date", () {
        const response = ProviderListResponse(
          providers: [
            ProviderInfo(
              id: "moonshotai",
              name: "Moonshot AI",
              models: {
                "kimi-k2-thinking": ProviderModel(
                  id: "moonshotai/kimi-k2-thinking",
                  providerID: "moonshotai",
                  name: "Kimi K2 Thinking",
                  family: "kimi-thinking",
                  releaseDate: "2025-11-06",
                ),
              },
            ),
          ],
          defaults: {},
          connected: ["moonshotai"],
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
          const response = ProviderListResponse(
            providers: [
              ProviderInfo(
                id: "kimi-for-coding",
                name: "Kimi For Coding",
                models: {
                  "kimi-k2-thinking": ProviderModel(
                    id: "kimi-k2-thinking",
                    providerID: "kimi-for-coding",
                    name: "Kimi K2 Thinking",
                    family: "kimi-thinking",
                    releaseDate: "2025-11",
                  ),
                  "k2p5": ProviderModel(
                    id: "k2p5",
                    providerID: "kimi-for-coding",
                    name: "Kimi K2.5",
                    family: "kimi-thinking",
                    releaseDate: "2026-01",
                  ),
                  "k2p6": ProviderModel(
                    id: "k2p6",
                    providerID: "kimi-for-coding",
                    name: "Kimi K2.6",
                    family: "kimi-thinking",
                    releaseDate: "2026-04",
                  ),
                },
              ),
            ],
            defaults: {},
            connected: ["kimi-for-coding"],
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
        const response = ProviderListResponse(
          providers: [
            ProviderInfo(
              id: "openai",
              name: "OpenAI",
              models: {
                "gpt-4.1": ProviderModel(
                  id: "openai/gpt-4.1",
                  providerID: "openai",
                  name: "GPT-4.1",
                  family: "gpt-4.1",
                ),
              },
            ),
          ],
          defaults: {},
          connected: ["openai"],
        );

        final mapped = mapProviderResponse(response: response);
        expect(mapped.providers.single.models.single.releaseDate, isNull);
      });

      test("leaves releaseDate null when the value is unparseable", () {
        const response = ProviderListResponse(
          providers: [
            ProviderInfo(
              id: "openai",
              name: "OpenAI",
              models: {
                "gpt-4.1": ProviderModel(
                  id: "openai/gpt-4.1",
                  providerID: "openai",
                  name: "GPT-4.1",
                  family: "gpt-4.1",
                  releaseDate: "not-a-date",
                ),
              },
            ),
          ],
          defaults: {},
          connected: ["openai"],
        );

        final mapped = mapProviderResponse(response: response);
        expect(mapped.providers.single.models.single.releaseDate, isNull);
      });
    });
  });
}
