import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/models/codex_model_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_model_repository.dart";
import "package:test/test.dart";

void main() {
  group("CodexAppServerApi", () {
    test("decodes the typed model/list response", () async {
      final client = _StubClient(
        response: const {
          "data": [
            {
              "id": "gpt-5.5",
              "displayName": "GPT-5.5",
              "hidden": false,
              "supportedReasoningEfforts": [
                {
                  "reasoningEffort": "high",
                  "description": "Deep reasoning",
                },
              ],
              "defaultReasoningEffort": "high",
              "isDefault": true,
            },
          ],
          "nextCursor": "next-page",
        },
      );

      final response = await CodexAppServerApi(client: client).listModels();

      expect(client.method, "model/list");
      expect(client.params, isEmpty);
      expect(response.nextCursor, "next-page");
      expect(response.data.single.id, "gpt-5.5");
      expect(
        response.data.single.supportedReasoningEfforts?.single.reasoningEffort,
        "high",
      );
    });

    test("rejects a non-object model/list response", () async {
      final api = CodexAppServerApi(client: _StubClient(response: const []));

      await expectLater(api.listModels(), throwsStateError);
    });

    test("preserves supported effort shapes while skipping unknown list entries", () async {
      final api = CodexAppServerApi(
        client: _StubClient(
          response: const {
            "data": [
              false,
              {
                "id": "gpt-5.5",
                "supportedReasoningEfforts": [
                  "low",
                  {"reasoningEffort": "high", "description": "Deep"},
                  7,
                ],
              },
            ],
          },
        ),
      );

      final response = await api.listModels();

      expect(response.data, hasLength(1));
      expect(
        response.data.single.supportedReasoningEfforts?.map(
          (option) => option.reasoningEffort,
        ),
        ["low", "high"],
      );
    });

    test("rejects a model/list response whose data field is not a list", () async {
      final api = CodexAppServerApi(
        client: _StubClient(response: const {"data": "invalid"}),
      );

      await expectLater(api.listModels(), throwsFormatException);
    });

    test("rejects a non-list supported reasoning-effort field", () async {
      final api = CodexAppServerApi(
        client: _StubClient(
          response: const {
            "data": [
              {
                "id": "gpt-5.5",
                "supportedReasoningEfforts": "invalid",
              },
            ],
          },
        ),
      );

      await expectLater(api.listModels(), throwsFormatException);
    });
  });

  group("CodexModelRepository", () {
    test("filters hidden models and falls back to the id for a blank display name", () async {
      final repository = CodexModelRepository(
        appServerApi: _StubAppServerApi(
          response: const CodexModelListResponseDto(
            data: [
              CodexModelDto(
                id: "gpt-visible",
                displayName: "  ",
                hidden: false,
                supportedReasoningEfforts: [],
                defaultReasoningEffort: null,
                isDefault: true,
              ),
              CodexModelDto(
                id: "gpt-hidden",
                displayName: "Hidden",
                hidden: true,
                supportedReasoningEfforts: [],
                defaultReasoningEffort: null,
                isDefault: false,
              ),
              CodexModelDto(
                id: "  ",
                displayName: "Missing identity",
                hidden: false,
                supportedReasoningEfforts: [],
                defaultReasoningEffort: null,
                isDefault: false,
              ),
            ],
            nextCursor: null,
          ),
        ),
      );

      final catalog = await repository.listModels();

      expect(catalog.models, hasLength(1));
      expect(catalog.models.single.id, "gpt-visible");
      expect(catalog.models.single.name, "gpt-visible");
      expect(catalog.defaultModelID, "gpt-visible");
    });

    test("lists reasoning efforts strongest first, declares the default, and removes duplicates", () async {
      final repository = CodexModelRepository(
        appServerApi: _StubAppServerApi(
          response: const CodexModelListResponseDto(
            data: [
              CodexModelDto(
                id: "gpt-5.5",
                displayName: "GPT-5.5",
                hidden: false,
                supportedReasoningEfforts: [
                  CodexReasoningEffortOptionDto(
                    reasoningEffort: "low",
                    description: "Fast",
                  ),
                  CodexReasoningEffortOptionDto(
                    reasoningEffort: "medium",
                    description: "Balanced",
                  ),
                  CodexReasoningEffortOptionDto(
                    reasoningEffort: "high",
                    description: "Deep",
                  ),
                  CodexReasoningEffortOptionDto(
                    reasoningEffort: "medium",
                    description: "Duplicate",
                  ),
                ],
                defaultReasoningEffort: "medium",
                isDefault: false,
              ),
            ],
            nextCursor: null,
          ),
        ),
      );

      final catalog = await repository.listModels();

      expect(catalog.models.single.variants, ["high", "medium", "low"]);
      expect(catalog.models.single.defaultVariant, "medium");
    });

    test("lists models newest generation first, then Astra, Sol, Terra, Luna, bare, other", () async {
      CodexModelDto model(String id) => CodexModelDto(
        id: id,
        displayName: id,
        hidden: false,
        supportedReasoningEfforts: const [],
        defaultReasoningEffort: null,
        isDefault: false,
      );
      final repository = CodexModelRepository(
        appServerApi: _StubAppServerApi(
          response: CodexModelListResponseDto(
            data: [
              for (final id in [
                "gpt-5.6-sol",
                "codex-auto-review",
                "gpt-5.5-mini",
                "gpt-6-luna",
                "gpt-5.5",
                "gpt-5.6-terra",
                "gpt-6-astra",
                "gpt-5.6-luna",
                "gpt-5.4-mini",
                "gpt-5.3-codex-spark",
                "gpt-5.5-codex",
              ])
                model(id),
            ],
            nextCursor: null,
          ),
        ),
      );

      final catalog = await repository.listModels();

      expect(catalog.models.map((model) => model.id), [
        "gpt-6-astra",
        "gpt-6-luna",
        "gpt-5.6-sol",
        "gpt-5.6-terra",
        "gpt-5.6-luna",
        "gpt-5.5",
        "gpt-5.5-mini",
        "gpt-5.5-codex",
        "gpt-5.4-mini",
        "gpt-5.3-codex-spark",
        "codex-auto-review",
      ]);
    });
  });
}

class _StubClient({required final Object? response}) extends CodexAppServerClient {
  this : super(serverUrl: "ws://127.0.0.1:0");

  String? method;
  Object? params;

  @override
  Future<dynamic> request({
    required String method,
    Object? params,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    this.method = method;
    this.params = params;
    return response;
  }
}

class _StubAppServerApi({required final CodexModelListResponseDto response}) extends CodexAppServerApi {
  this
    : super(
        client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"),
      );

  @override
  Future<CodexModelListResponseDto> listModels() async => response;
}
