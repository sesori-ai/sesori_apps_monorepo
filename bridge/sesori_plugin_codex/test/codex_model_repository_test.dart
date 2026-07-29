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

    test("orders the default reasoning effort first and removes duplicates", () async {
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

      expect(catalog.models.single.variants, ["medium", "low", "high"]);
    });
  });
}

class _StubClient extends CodexAppServerClient {
  _StubClient({required this.response}) : super(serverUrl: "ws://127.0.0.1:0");

  final Object? response;
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

class _StubAppServerApi extends CodexAppServerApi {
  _StubAppServerApi({required this.response})
    : super(
        client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"),
      );

  final CodexModelListResponseDto response;

  @override
  Future<CodexModelListResponseDto> listModels() async => response;
}
