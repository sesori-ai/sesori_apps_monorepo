import "package:acp_plugin/acp_plugin.dart" show AcpInitializeResult, AcpNewSessionResult;

import "../api/grok_acp_api.dart";
import "../api/models/grok_protocol_dto.dart";
import "../models/grok_model_catalog.dart";

/// Validates Grok identity and maps its legacy model-state wire shape.
class GrokCatalogRepository({required final GrokAcpApi _api}) {
  Future<GrokModelCatalog> discoverCatalog({
    required String cwd,
    required Duration timeout,
  }) async => mapInitializeResult(
    result: await _api.probeCatalog(cwd: cwd, timeout: timeout),
  );

  GrokModelCatalog mapInitializeResult({required AcpInitializeResult result}) {
    final envelope = GrokModelStateEnvelopeDto.fromJson({...result.raw, "models": null});
    final metadata = envelope.metadata;
    if (metadata?.grokShell != true) throw StateError("ACP initialize result is not from Grok Build");
    final state = metadata?.modelState;
    if (state == null) throw StateError("Grok initialize result omitted model state");
    return _mapState(state: state);
  }

  GrokModelCatalog? mapSessionResult({required AcpNewSessionResult result}) {
    final state = GrokModelStateEnvelopeDto.fromJson({...result.raw, "_meta": null}).models;
    return state == null ? null : _mapState(state: state);
  }

  GrokModelCatalog _mapState({required GrokSessionModelStateDto state}) {
    final models = <GrokCatalogModel>[];
    for (final entry in state.availableModels) {
      final id = entry.modelId;
      if (id == null || id.trim().isEmpty) continue;
      final metadata = entry.metadata;
      final effortOptions = (metadata?.supportsReasoningEffort ?? false)
          ? metadata?.reasoningEfforts ?? const <GrokReasoningEffortOptionDto>[]
          : const <GrokReasoningEffortOptionDto>[];
      final efforts = _reasoningEfforts(options: effortOptions);
      final currentEffort = metadata?.reasoningEffort;
      final name = entry.name?.trim();
      models.add(
        GrokCatalogModel(
          id: id,
          name: name == null || name.isEmpty ? id : name,
          reasoningEfforts: efforts.values,
          defaultReasoningEffort: efforts.defaultValue,
          currentReasoningEffort: currentEffort != null && efforts.values.contains(currentEffort)
              ? currentEffort
              : null,
        ),
      );
    }
    final currentModelId = state.currentModelId;
    return GrokModelCatalog(
      models: models,
      currentModelId: currentModelId != null && models.any((model) => model.id == currentModelId)
          ? currentModelId
          : null,
    );
  }

  ({List<String> values, String? defaultValue}) _reasoningEfforts({
    required List<GrokReasoningEffortOptionDto> options,
  }) {
    final values = <String>[];
    String? defaultValue;
    for (final option in options) {
      final value = option.value;
      if (value == null || value.trim().isEmpty) continue;
      values.add(value);
      if (option.isDefault) defaultValue ??= value;
    }
    final defaultIndex = defaultValue == null ? -1 : values.indexOf(defaultValue);
    if (defaultIndex > 0) values.insert(0, values.removeAt(defaultIndex));
    return (values: List.unmodifiable(values), defaultValue: defaultValue);
  }
}
