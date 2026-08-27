import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:grok_plugin/src/api/grok_acp_api.dart";
import "package:grok_plugin/src/repositories/grok_catalog_repository.dart";
import "package:test/test.dart";

void main() {
  final repository = GrokCatalogRepository(api: _FakeGrokAcpApi());

  test("maps initialize model state without interpreting opaque ids", () {
    final catalog = repository.mapInitializeResult(
      result: AcpInitializeResult.fromJson(_fixture(name: "initialize.json")),
    );

    expect(catalog.currentModel?.id, "synthetic:model-alpha");
    expect(catalog.models.map((model) => model.id), [
      "synthetic:model-alpha",
      "opaque/provider:model-beta",
    ]);
    expect(catalog.models.first.reasoningEfforts, ["high", "low"]);
    expect(catalog.models.first.currentReasoningEffort, "high");
    expect(catalog.models.last.reasoningEfforts, isEmpty);
  });

  test("maps session state and skips malformed model and effort entries", () {
    final result = AcpNewSessionResult.fromJson({
      "sessionId": "s1",
      "models": {
        "currentModelId": "missing-model",
        "availableModels": [
          {"modelId": "", "name": "Invalid", "description": null},
          {
            "modelId": "opaque:model",
            "name": " ",
            "description": null,
            "_meta": {
              "supportsReasoningEffort": true,
              "reasoningEffort": "unknown",
              "reasoningEfforts": [
                {"value": null, "default": true},
                {"value": "medium", "default": true},
              ],
            },
          },
        ],
      },
    });

    final catalog = repository.mapSessionResult(result: result)!;
    expect(catalog.currentModel, isNull);
    expect(catalog.models.single.id, "opaque:model");
    expect(catalog.models.single.name, "opaque:model");
    expect(catalog.models.single.reasoningEfforts, ["medium"]);
    expect(catalog.models.single.currentReasoningEffort, isNull);
  });

  test("accepts an explicit empty catalog but rejects missing Grok identity", () {
    final empty = repository.mapInitializeResult(
      result: AcpInitializeResult.fromJson({
        "protocolVersion": 1,
        "_meta": {"grokShell": true, "modelState": _emptyModelState},
      }),
    );
    expect(empty.models, isEmpty);

    expect(
      () => repository.mapInitializeResult(
        result: AcpInitializeResult.fromJson({
          "protocolVersion": 1,
          "_meta": {"grokShell": false, "modelState": _emptyModelState},
        }),
      ),
      throwsStateError,
    );
  });
}

const Map<String, dynamic> _emptyModelState = {
  "currentModelId": null,
  "availableModels": <Object?>[],
};

Map<String, dynamic> _fixture({required String name}) {
  final decoded = jsonDecode(File("test/fixtures/protocol/v1/$name").readAsStringSync());
  return (decoded! as Map<dynamic, dynamic>).cast<String, dynamic>();
}

class _FakeGrokAcpApi() implements GrokAcpApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
