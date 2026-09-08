import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_app_server_api.dart";
import "../api/models/codex_model_dto.dart";

typedef CodexModelCatalog = ({
  String? defaultModelID,
  List<PluginModel> models,
});

/// Maps Codex's app-server model catalog into selectable plugin models,
/// listed strongest first through [CatalogStrengthOrder].
class CodexModelRepository({required final CodexAppServerApi _appServerApi}) {
  Future<CodexModelCatalog> listModels() async {
    final response = await _appServerApi.listModels();
    String? defaultModelID;
    final models = <PluginModel>[];
    for (final model in response.data) {
      if (model.hidden ?? false) continue;
      final id = _usefulText(value: model.id);
      if (id == null) continue;
      if (model.isDefault ?? false) defaultModelID = id;
      final variants = _reasoningEffortVariants(model: model);
      final defaultEffort = _usefulText(value: model.defaultReasoningEffort);
      models.add(
        PluginModel(
          id: id,
          name: _usefulText(value: model.displayName) ?? id,
          variants: variants,
          defaultVariant: variants.contains(defaultEffort) ? defaultEffort : null,
          family: null,
          isAvailable: true,
          releaseDate: null,
        ),
      );
    }
    return (defaultModelID: defaultModelID, models: CatalogStrengthOrder.models(models, idOf: (model) => model.id));
  }

  List<String> _reasoningEffortVariants({required CodexModelDto model}) {
    final efforts = <String>[];
    for (final option in model.supportedReasoningEfforts ?? const <CodexReasoningEffortOptionDto>[]) {
      final effort = _usefulText(value: option.reasoningEffort);
      if (effort != null && !efforts.contains(effort)) efforts.add(effort);
    }
    return CatalogStrengthOrder.variants(efforts);
  }

  String? _usefulText({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
