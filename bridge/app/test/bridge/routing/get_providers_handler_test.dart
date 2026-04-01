import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/get_providers_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
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
      await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(plugin.lastGetProvidersConnectedOnly, isTrue);
    });

    test("connectedOnly remains true when explicitly set to false", () async {
      await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {"connectedOnly": "false"},
        fragment: null,
      );
      expect(plugin.lastGetProvidersConnectedOnly, isTrue);
    });

    test("connectedOnly is true when explicitly set to true", () async {
      await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {"connectedOnly": "true"},
        fragment: null,
      );
      expect(plugin.lastGetProvidersConnectedOnly, isTrue);
    });

    test("connectedOnly remains true for uppercase FALSE", () async {
      await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {"connectedOnly": "FALSE"},
        fragment: null,
      );
      expect(plugin.lastGetProvidersConnectedOnly, isTrue);
    });

    test("connectedOnly remains true for invalid values", () async {
      await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {"connectedOnly": "maybe"},
        fragment: null,
      );
      expect(plugin.lastGetProvidersConnectedOnly, isTrue);
    });

    // ── Response format ─────────────────────────────────────────────────────

    test("returns 200 with application/json content-type", () async {
      final response = await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
    });

    test("returns empty items list when plugin has no providers", () async {
      final response = await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      expect(body["items"] as List, isEmpty);
    });

    test("response includes connectedOnly flag set to true by default", () async {
      final response = await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      expect(body["connectedOnly"], isTrue);
    });

    test("response includes connectedOnly flag set to true when specified false", () async {
      final response = await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {"connectedOnly": "false"},
        fragment: null,
      );
      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      expect(body["connectedOnly"], isTrue);
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

      final response = await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final items = body["items"] as List<dynamic>;
      expect(items, hasLength(1));
      final provider = items[0] as Map<String, dynamic>;
      expect(provider["id"], equals("anthropic"));
      expect(provider["name"], equals("Anthropic"));
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

      final response = await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final items = body["items"] as List<dynamic>;
      final provider = items[0] as Map<String, dynamic>;
      expect(provider["defaultModelID"], equals("gpt-4o"));
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

      final response = await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final items = body["items"] as List<dynamic>;
      final provider = items[0] as Map<String, dynamic>;
      expect(provider["defaultModelID"], isNull);
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

      final response = await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final items = body["items"] as List<dynamic>;
      final provider = items[0] as Map<String, dynamic>;
      final models = provider["models"] as Map<String, dynamic>;
      expect(models, hasLength(2));

      final opus = models["claude-3-opus"] as Map<String, dynamic>;
      expect(opus["id"], equals("claude-3-opus"));
      expect(opus["providerID"], equals("anthropic"));
      expect(opus["name"], equals("Claude 3 Opus"));
      expect(opus["family"], equals("claude-3"));

      final sonnet = models["claude-3-sonnet"] as Map<String, dynamic>;
      expect(sonnet["id"], equals("claude-3-sonnet"));
      expect(sonnet["providerID"], equals("anthropic"));
      expect(sonnet["name"], equals("Claude 3 Sonnet"));
      expect(sonnet["family"], isNull);
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

      final response = await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final items = body["items"] as List<dynamic>;
      final provider = items[0] as Map<String, dynamic>;
      expect(provider["models"] as Map, isEmpty);
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

      final response = await handler.handleInternal(
        makeRequest("GET", "/provider"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final items = body["items"] as List<dynamic>;
      expect(items, hasLength(3));
    });
  });
}
