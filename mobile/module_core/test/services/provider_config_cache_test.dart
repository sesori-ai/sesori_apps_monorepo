import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../lib/src/services/provider_config_cache.dart";

void main() {
  group("ProviderConfigCache", () {
    late ProviderConfigCache cache;

    setUp(() {
      cache = ProviderConfigCache();
    });

    test("get returns null for unknown projectId", () {
      expect(cache.get(projectId: "unknown"), isNull);
    });

    test("has returns false for unknown projectId", () {
      expect(cache.has(projectId: "unknown"), isFalse);
    });

    test("set and get roundtrip", () {
      final response = ProviderListResponse(
        items: [
          ProviderInfo(
            id: "anthropic",
            name: "Anthropic",
            models: {},
            defaultModelID: "claude-sonnet",
          ),
        ],
        connectedOnly: true,
      );

      cache.set(projectId: "project-1", response: response);

      expect(cache.has(projectId: "project-1"), isTrue);
      expect(cache.get(projectId: "project-1"), equals(response));
    });

    test("clear removes all entries", () {
      cache.set(
        projectId: "project-1",
        response: ProviderListResponse(items: [], connectedOnly: true),
      );
      cache.set(
        projectId: "project-2",
        response: ProviderListResponse(items: [], connectedOnly: true),
      );

      cache.clear();

      expect(cache.has(projectId: "project-1"), isFalse);
      expect(cache.has(projectId: "project-2"), isFalse);
    });

    test("different projectIds are independent", () {
      final response1 = ProviderListResponse(
        items: [
          ProviderInfo(
            id: "anthropic",
            name: "Anthropic",
            models: {},
            defaultModelID: "claude",
          ),
        ],
        connectedOnly: true,
      );
      final response2 = ProviderListResponse(
        items: [
          ProviderInfo(
            id: "openai",
            name: "OpenAI",
            models: {},
            defaultModelID: "gpt-4",
          ),
        ],
        connectedOnly: true,
      );

      cache.set(projectId: "project-1", response: response1);
      cache.set(projectId: "project-2", response: response2);

      expect(cache.get(projectId: "project-1"), equals(response1));
      expect(cache.get(projectId: "project-2"), equals(response2));
    });
  });
}
