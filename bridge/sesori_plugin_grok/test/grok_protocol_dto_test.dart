import "dart:convert";
import "dart:io";

import "package:grok_plugin/src/api/models/grok_protocol_dto.dart";
import "package:test/test.dart";

void main() {
  test("parses released initialize model-state structure", () {
    final fixture = _fixture(name: "initialize.json");
    final metadata = _map(value: fixture["_meta"]);
    final modelState = GrokSessionModelStateDto.fromJson(_map(value: metadata["modelState"]));

    expect(metadata["grokShell"], isTrue);
    expect(metadata["agentVersion"], "1.0.5");
    expect(modelState.currentModelId, "synthetic:model-alpha");
    expect(modelState.availableModels, hasLength(2));

    final primary = modelState.availableModels.first;
    expect(primary.modelId, "synthetic:model-alpha");
    expect(primary.name, "Model Alpha");
    expect(primary.metadata?.supportsReasoningEffort, isTrue);
    expect(primary.metadata?.reasoningEffort, "high");
    expect(primary.metadata?.reasoningEfforts.map((option) => option.value), ["low", "high"]);
    expect(primary.metadata?.reasoningEfforts.last.isDefault, isTrue);
  });

  test("parses model state from session responses without interpreting ids", () {
    final fixture = _fixture(name: "session.json");
    final modelState = GrokSessionModelStateDto.fromJson(_map(value: fixture["models"]));

    expect(modelState.currentModelId, "opaque/provider:model-beta");
    expect(modelState.availableModels.last.modelId, "opaque/provider:model-beta");
    expect(modelState.availableModels.last.metadata?.supportsReasoningEffort, isFalse);
    expect(modelState.availableModels.last.metadata?.reasoningEfforts, isEmpty);
  });

  test("accepts omitted optional model metadata", () {
    final modelState = GrokSessionModelStateDto.fromJson({
      "availableModels": [
        {
          "modelId": "future-model",
          "name": "Future Model",
          "description": null,
        },
      ],
      "currentModelId": "future-model",
    });

    expect(modelState.availableModels.single.metadata, isNull);
  });

  test("keeps the reasoning option default field on the wire", () {
    const option = GrokReasoningEffortOptionDto(
      id: "high",
      value: "high",
      label: "High",
      description: "Synthetic fixture",
      isDefault: true,
    );

    expect(option.toJson()["default"], isTrue);
    expect(option.toJson(), isNot(contains("isDefault")));
  });
}

Map<String, dynamic> _fixture({required String name}) {
  final decoded = jsonDecode(File("test/fixtures/protocol/v1/$name").readAsStringSync());
  return _map(value: decoded);
}

Map<String, dynamic> _map({required Object? value}) => (value! as Map<dynamic, dynamic>).cast<String, dynamic>();
