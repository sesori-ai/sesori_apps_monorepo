/// One valid Grok model and its exact advertised reasoning values.
class GrokCatalogModel({
  required final String id,
  required final String name,
  required List<String> reasoningEfforts,
  required final String? defaultReasoningEffort,
  required final String? currentReasoningEffort,
}) {
  final List<String> reasoningEfforts = List.unmodifiable(reasoningEfforts);
}

/// Immutable last-good Grok model catalog.
class GrokModelCatalog({
  required List<GrokCatalogModel> models,
  required String? currentModelId,
}) {
  final List<GrokCatalogModel> models = List.unmodifiable(models);
  final String? _currentModelId = currentModelId;

  GrokCatalogModel? get currentModel => _currentModelId == null ? null : modelById(id: _currentModelId);
  String? get currentModelId => currentModel?.id;
  GrokCatalogModel? get defaultModel => currentModel ?? models.firstOrNull;

  GrokCatalogModel? modelById({required String id}) {
    for (final model in models) {
      if (model.id == id) return model;
    }
    return null;
  }
}
