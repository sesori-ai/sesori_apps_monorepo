import "dart:convert";
import "dart:io";

import "package:grok_plugin/src/api/models/grok_protocol_dto.dart";
import "package:grok_plugin/src/models/grok_subagent_status.dart";
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

  test("parses captured child-cancel application envelope structure", () {
    final envelope = GrokSubagentCancelResponseEnvelopeDto.fromJson(
      _fixture(name: "subagent_cancel_response.json"),
    );

    expect(envelope.result.subagentId, "synthetic-child");
    expect(envelope.result.cancelled, isFalse);
    expect(envelope.result.outcome.kind, GrokSubagentCancelOutcomeKind.alreadyFinished);
    expect(envelope.result.outcome.status, GrokSubagentStatus.completed);
  });

  test("requires one object result containing the child-cancel DTO", () {
    expect(
      () => GrokSubagentCancelResponseEnvelopeDto.fromJson(<String, dynamic>{}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => GrokSubagentCancelResponseEnvelopeDto.fromJson({"result": <Object?>[]}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => GrokSubagentCancelResponseEnvelopeDto.fromJson({
        "subagentId": "synthetic-child",
        "cancelled": true,
        "outcome": {"kind": "cancelled"},
      }),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => GrokSubagentCancelResponseEnvelopeDto.fromJson({
        "result": {
          "subagentId": "synthetic-child",
          "cancelled": "yes",
          "outcome": {"kind": "cancelled"},
        },
      }),
      throwsA(isA<TypeError>()),
    );
  });
}

Map<String, dynamic> _fixture({required String name}) {
  final decoded = jsonDecode(File("test/fixtures/protocol/v1/$name").readAsStringSync());
  return _map(value: decoded);
}

Map<String, dynamic> _map({required Object? value}) => (value! as Map<dynamic, dynamic>).cast<String, dynamic>();
