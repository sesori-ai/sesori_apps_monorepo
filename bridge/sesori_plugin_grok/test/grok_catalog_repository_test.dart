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
    expect(catalog.models.first.defaultReasoningEffort, "high");
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
                7,
                {"value": 7, "default": true},
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
    expect(catalog.models.single.defaultReasoningEffort, "medium");
    expect(catalog.models.single.currentReasoningEffort, isNull);
  });

  test("ignores malformed irrelevant envelope branches", () {
    final initialize = _fixture(name: "initialize.json")..["models"] = 7;
    expect(
      repository.mapInitializeResult(result: AcpInitializeResult.fromJson(initialize)).currentModel?.id,
      "synthetic:model-alpha",
    );

    final initializeMetadata = initialize["_meta"] as Map<String, dynamic>;
    final session = AcpNewSessionResult.fromJson({
      "sessionId": "s1",
      "models": initializeMetadata["modelState"],
      "_meta": 7,
    });
    expect(repository.mapSessionResult(result: session)?.currentModel?.id, "synthetic:model-alpha");
  });

  test("retains valid models while sanitizing malformed siblings and optional fields", () {
    final result = AcpNewSessionResult.fromJson({
      "sessionId": "s1",
      "models": {
        "currentModelId": 7,
        "availableModels": [
          7,
          {1: "non-string key"},
          {"modelId": 7, "name": "Invalid identity"},
          {"modelId": "plain", "name": 7, "description": false, "_meta": "invalid"},
          {
            "modelId": "unsupported",
            "_meta": {
              "supportsReasoningEffort": "invalid",
              "reasoningEfforts": [
                {"value": "low", "default": true},
              ],
            },
          },
          {
            "modelId": "reasoning",
            "name": "Reasoning",
            "_meta": {
              "supportsReasoningEffort": true,
              "reasoningEffort": 7,
              "reasoningEfforts": [
                {1: "non-string key", "value": "xhigh"},
                {"value": 7, "default": true},
                {"value": "low", "default": true},
              ],
            },
          },
        ],
      },
    });

    final catalog = repository.mapSessionResult(result: result)!;
    expect(catalog.currentModel, isNull);
    expect(catalog.models.map((model) => model.id), ["plain", "unsupported", "reasoning"]);
    expect(catalog.models.first.name, "plain");
    expect(catalog.models.take(2).every((model) => model.reasoningEfforts.isEmpty), isTrue);
    expect(catalog.models.last.reasoningEfforts, ["low"]);
    expect(catalog.models.last.defaultReasoningEffort, "low");
    expect(catalog.models.last.currentReasoningEffort, isNull);
  });

  test("preserves a selected model when its optional effort container is malformed", () {
    const modelState = {
      "currentModelId": "opaque:model",
      "availableModels": [
        {
          "modelId": "opaque:model",
          "name": "Opaque model",
          "_meta": {
            "supportsReasoningEffort": true,
            "reasoningEffort": "high",
            "reasoningEfforts": "invalid",
          },
        },
      ],
    };
    final catalogs = [
      repository.mapInitializeResult(
        result: AcpInitializeResult.fromJson({
          "protocolVersion": 1,
          "_meta": {"grokShell": true, "modelState": modelState},
        }),
      ),
      repository.mapSessionResult(
        result: AcpNewSessionResult.fromJson({"sessionId": "s1", "models": modelState}),
      )!,
    ];

    for (final catalog in catalogs) {
      expect(catalog.currentModel?.id, "opaque:model");
      expect(catalog.models.single.reasoningEfforts, isEmpty);
      expect(catalog.models.single.defaultReasoningEffort, isNull);
      expect(catalog.models.single.currentReasoningEffort, isNull);
    }
  });

  test("rejects a malformed available-models container without replacing it with empty", () {
    final result = AcpNewSessionResult.fromJson({
      "sessionId": "s1",
      "models": {"currentModelId": null, "availableModels": "invalid"},
    });
    expect(
      () => repository.mapSessionResult(result: result),
      throwsA(isA<FormatException>()),
    );
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
