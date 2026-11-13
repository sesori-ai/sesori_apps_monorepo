import "package:collection/collection.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/models/session_options/effort_level.dart";
import "../foundation/models/session_options/model_orbits.dart";
import "../utils/model_filter/default_model_selector.dart";
import "session_selection_calculator.dart";

/// Decides whether a catalog shows as orbits and builds them.
///
/// Pure: it reads the catalog and the selection, decided from the data alone,
/// never from the harness. Const-constructed by its callers.
class const ModelOrbitsCalculator() {
  /// At most this many models get a ring.
  static const int maxRings = 4;

  static const SessionSelectionCalculator _selection = SessionSelectionCalculator();
  static const DefaultModelSelector _defaultModelSelector = DefaultModelSelector();

  /// The orbits for [providers] with [selected] chosen, or null when the
  /// catalog is not orbit-shaped: more or fewer than one provider with
  /// available models, a level off the shared ladder, no level anywhere, or
  /// no selected model that the catalog offers.
  ModelOrbits? orbits({required List<ProviderInfo> providers, required AgentModel? selected}) {
    if (selected == null) return null;
    final offering = providers.where((provider) => provider.models.values.any((model) => model.isAvailable)).toList();
    if (offering.length != 1) return null;
    final provider = offering.single;
    final models = provider.models.values.where((model) => model.isAvailable).toList();

    final levelsByModelID = <String, List<OrbitLevel>>{};
    for (final model in models) {
      final levels = _levels(providers: providers, providerID: provider.id, model: model);
      if (levels == null) return null;
      levelsByModelID[model.id] = levels;
    }
    if (levelsByModelID.values.every((levels) => levels.isEmpty)) return null;

    final currentModel = selected.providerID == provider.id ? provider.models[selected.modelID] : null;
    if (currentModel == null || !currentModel.isAvailable) return null;

    final ringModels = _ringModels(models: models, current: currentModel);
    final rings = [
      for (final model in ringModels)
        OrbitRing(
          providerID: provider.id,
          modelID: model.id,
          name: model.name,
          levels: levelsByModelID[model.id] ?? const [],
          fastMode: model.fastMode,
        ),
    ];
    final current = rings.firstWhere((ring) => ring.modelID == currentModel.id);
    final offeredLevels = {
      for (final ring in rings) ...ring.levels.map((level) => level.level),
    };
    return ModelOrbits(
      rings: rings,
      levels: EffortLevel.values.where(offeredLevels.contains).toList(growable: false),
      totalModels: models.length,
      allRingsFast: rings.every((ring) => _hasFastMode(support: ring.fastMode)),
      current: current,
      currentLevel: current.levels.firstWhereOrNull((level) => level.variant.id == selected.variant)?.level,
    );
  }

  /// [model]'s levels, weakest first, or null when one is off the ladder.
  List<OrbitLevel>? _levels({
    required List<ProviderInfo> providers,
    required String providerID,
    required ProviderModel model,
  }) {
    final levels = <OrbitLevel>[];
    final variants = _selection.availableVariants(
      providers: providers,
      model: AgentModel(providerID: providerID, modelID: model.id, variant: null),
    );
    for (final variant in variants) {
      final level = EffortLevel.tryParse(value: variant.id);
      if (level == null) return null;
      levels.add(OrbitLevel(level: level, variant: variant));
    }
    return levels..sortBy<num>((level) => level.level.index);
  }

  /// Each family's representative in order of the family's first appearance,
  /// the first [maxRings] of them, with [current] taking the last place when
  /// it is not among them. Kept in catalog order.
  List<ProviderModel> _ringModels({required List<ProviderModel> models, required ProviderModel current}) {
    final families = <String, List<ProviderModel>>{};
    for (final model in models) {
      (families[model.family ?? model.id] ??= []).add(model);
    }
    final representatives = families.values
        .map((group) => _defaultModelSelector.pickFromFamily(group: group))
        .whereType<ProviderModel>()
        .take(maxRings)
        .toList();
    if (!representatives.any((model) => model.id == current.id)) {
      if (representatives.length == maxRings) representatives.removeLast();
      representatives.add(current);
    }
    return representatives..sortBy<num>(models.indexOf);
  }

  bool _hasFastMode({required FastModeSupport? support}) => switch (support) {
    FastModeAvailable() || FastModeUnavailable() => true,
    null || FastModeSupportUnknown() => false,
  };
}
