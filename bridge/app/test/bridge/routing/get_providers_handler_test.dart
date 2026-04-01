import "package:sesori_bridge/src/bridge/routing/get_providers_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetProvidersHandler", () {
    late FakeBridgePlugin plugin;
    late GetProvidersHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetProvidersHandler(plugin);
    });

    tearDown(() => plugin.close());

    // ── Route matching ──────────────────────────────────────────────────────

    test("canHandle GET /provider", () {
      expect(handler.canHandle(makeRequest("GET", "/provider")), isTrue);
    });

    test("does not handle POST /provider", () {
      expect(handler.canHandle(makeRequest("POST", "/provider")), isFalse);
    });

    test("does not handle GET /project", () {
      expect(handler.canHandle(makeRequest("GET", "/project")), isFalse);
    });

    test("does not handle GET /provider/extra", () {
      expect(handler.canHandle(makeRequest("GET", "/provider/extra")), isFalse);
    });

    // ── Query parameter handling ────────────────────────────────────────────

    test("connectedOnly defaults to true when absent", () async {
      await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(plugin.lastGetProvidersConnectedOnly, isTrue);
    });

    test("connectedOnly remains true when explicitly set to false", () async {
      await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {"connectedOnly": "false"},
        fragment: null,
      );
      expect(plugin.lastGetProvidersConnectedOnly, isTrue);
    });

    test("connectedOnly is true when explicitly set to true", () async {
      await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {"connectedOnly": "true"},
        fragment: null,
      );
      expect(plugin.lastGetProvidersConnectedOnly, isTrue);
    });

    test("connectedOnly remains true for uppercase FALSE", () async {
      await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {"connectedOnly": "FALSE"},
        fragment: null,
      );
      expect(plugin.lastGetProvidersConnectedOnly, isTrue);
    });

    test("connectedOnly remains true for invalid values", () async {
      await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {"connectedOnly": "maybe"},
        fragment: null,
      );
      expect(plugin.lastGetProvidersConnectedOnly, isTrue);
    });

    // ── Response format ─────────────────────────────────────────────────────

    test("returns typed provider list response", () async {
      final response = await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response, isA<ProviderListResponse>());
    });

    test("returns empty items list when plugin has no providers", () async {
      final response = await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.items, isEmpty);
    });

    test("response includes connectedOnly flag set to true by default", () async {
      final response = await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.connectedOnly, isTrue);
    });

    test("response includes connectedOnly flag set to true when specified false", () async {
      final response = await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {"connectedOnly": "false"},
        fragment: null,
      );
      expect(response.connectedOnly, isTrue);
    });

    // ── Data transformation ─────────────────────────────────────────────────

    test("maps provider id and name fields", () async {
      plugin.providersResult = const PluginProvidersResult(
        providers: [
          PluginProvider.anthropic(
            id: "anthropic",
            name: "Anthropic",
            authType: PluginProviderAuthType.apiKey,
            models: [],
            defaultModelID: null,
          ),
        ],
      );

      final response = await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final provider = response.items[0];
      expect(response.items, hasLength(1));
      expect(provider.id, equals("anthropic"));
      expect(provider.name, equals("Anthropic"));
    });

    test("maps defaultModelID when present", () async {
      plugin.providersResult = const PluginProvidersResult(
        providers: [
          PluginProvider.openAI(
            id: "openai",
            name: "OpenAI",
            authType: PluginProviderAuthType.apiKey,
            models: [],
            defaultModelID: "gpt-4o",
          ),
        ],
      );

      final response = await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final provider = response.items[0];
      expect(provider.defaultModelID, equals("gpt-4o"));
    });

    test("defaultModelID is null when absent", () async {
      plugin.providersResult = const PluginProvidersResult(
        providers: [
          PluginProvider.google(
            id: "google",
            name: "Google",
            authType: PluginProviderAuthType.apiKey,
            models: [],
            defaultModelID: null,
          ),
        ],
      );

      final response = await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final provider = response.items[0];
      expect(provider.defaultModelID, isNull);
    });

    test("maps models with id, providerID, name, and family", () async {
      plugin.providersResult = const PluginProvidersResult(
        providers: [
          PluginProvider.anthropic(
            id: "anthropic",
            name: "Anthropic",
            authType: PluginProviderAuthType.apiKey,
            models: [
              PluginModel(id: "claude-3-opus", name: "Claude 3 Opus", family: "claude-3"),
              PluginModel(id: "claude-3-sonnet", name: "Claude 3 Sonnet"),
            ],
            defaultModelID: "claude-3-sonnet",
          ),
        ],
      );

      final response = await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final models = response.items[0].models;
      expect(models, hasLength(2));

      final opus = models["claude-3-opus"]!;
      expect(opus.id, equals("claude-3-opus"));
      expect(opus.providerID, equals("anthropic"));
      expect(opus.name, equals("Claude 3 Opus"));
      expect(opus.family, equals("claude-3"));

      final sonnet = models["claude-3-sonnet"]!;
      expect(sonnet.id, equals("claude-3-sonnet"));
      expect(sonnet.providerID, equals("anthropic"));
      expect(sonnet.name, equals("Claude 3 Sonnet"));
      expect(sonnet.family, isNull);
    });

    test("provider with no models has empty models map", () async {
      plugin.providersResult = const PluginProvidersResult(
        providers: [
          PluginProvider.custom(
            id: "empty-provider",
            name: "Empty Provider",
            authType: PluginProviderAuthType.unknown,
            models: [],
            defaultModelID: null,
          ),
        ],
      );

      final response = await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.items[0].models, isEmpty);
    });

    test("returns all providers when plugin returns multiple", () async {
      plugin.providersResult = const PluginProvidersResult(
        providers: [
          PluginProvider.anthropic(
            id: "anthropic",
            name: "Anthropic",
            authType: PluginProviderAuthType.apiKey,
            models: [],
            defaultModelID: null,
          ),
          PluginProvider.openAI(
            id: "openai",
            name: "OpenAI",
            authType: PluginProviderAuthType.apiKey,
            models: [],
            defaultModelID: null,
          ),
          PluginProvider.google(
            id: "google",
            name: "Google",
            authType: PluginProviderAuthType.apiKey,
            models: [],
            defaultModelID: null,
          ),
        ],
      );

      final response = await handler.handle(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.items, hasLength(3));
    });
  });
}
