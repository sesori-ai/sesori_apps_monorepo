import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_app_server_api.dart";
import "../api/models/codex_model_dto.dart";

typedef CodexModelCatalog = ({
  String? defaultModelID,
  List<PluginModel> models,
});

/// Where a model sits in the picker: newer generation first, then tier, then
/// the app-server's own order.
typedef _StrengthRank = ({List<int> generation, int tier, int serverIndex});

/// Maps Codex's app-server model catalog into selectable plugin models,
/// listed strongest first.
class CodexModelRepository({required final CodexAppServerApi _appServerApi}) {
  /// Tiers within one generation, strongest first. A bare model (`gpt-5.5`)
  /// follows the listed tiers; unlisted suffixes (`mini`, `codex-spark`)
  /// follow the bare model.
  static const List<String> _tiersByStrength = ["astra", "sol", "terra", "luna"];

  /// `gpt-<generation>[-<suffix>]`; anything else (`codex-auto-review`) sorts
  /// after every generation in app-server order.
  static final RegExp _modelId = RegExp(r"^gpt-(\d+(?:\.\d+)*)(?:-(.+))?$");

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
    return (defaultModelID: defaultModelID, models: _byStrength(models));
  }

  List<PluginModel> _byStrength(List<PluginModel> models) {
    final ranked = [
      for (final (index, model) in models.indexed) (rank: _rank(id: model.id, serverIndex: index), model: model),
    ]..sort((a, b) => _compareRanks(a.rank, b.rank));
    return [for (final entry in ranked) entry.model];
  }

  _StrengthRank _rank({required String id, required int serverIndex}) {
    final match = _modelId.firstMatch(id.toLowerCase());
    final version = match?.group(1);
    if (match == null || version == null) return (generation: const [], tier: 0, serverIndex: serverIndex);
    final generation = [for (final part in version.split(".")) int.parse(part)];
    final suffix = match.group(2);
    final tier = suffix == null
        ? _tiersByStrength.length
        : switch (_tiersByStrength.indexOf(suffix)) {
            -1 => _tiersByStrength.length + 1,
            final known => known,
          };
    return (generation: generation, tier: tier, serverIndex: serverIndex);
  }

  static int _compareRanks(_StrengthRank a, _StrengthRank b) {
    final parts = a.generation.length > b.generation.length ? a.generation.length : b.generation.length;
    for (var i = 0; i < parts; i++) {
      final aPart = i < a.generation.length ? a.generation[i] : 0;
      final bPart = i < b.generation.length ? b.generation[i] : 0;
      if (aPart != bPart) return bPart.compareTo(aPart);
    }
    final byTier = a.tier.compareTo(b.tier);
    return byTier != 0 ? byTier : a.serverIndex.compareTo(b.serverIndex);
  }

  /// Strongest first: the app-server lists efforts weakest first (`low` up to
  /// `ultra`), so its order is reversed.
  List<String> _reasoningEffortVariants({required CodexModelDto model}) {
    final efforts = <String>[];
    for (final option in model.supportedReasoningEfforts ?? const <CodexReasoningEffortOptionDto>[]) {
      final effort = _usefulText(value: option.reasoningEffort);
      if (effort != null && !efforts.contains(effort)) efforts.add(effort);
    }
    return efforts.reversed.toList();
  }

  String? _usefulText({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
