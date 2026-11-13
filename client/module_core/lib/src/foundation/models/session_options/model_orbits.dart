import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "effort_level.dart";

part "model_orbits.freezed.dart";

/// One effort level a ring's model offers, with the variant that selects it.
@Freezed()
sealed class OrbitLevel with _$OrbitLevel {
  const factory({
    required EffortLevel level,
    required SessionVariant variant,
  }) = _OrbitLevel;
}

/// One model drawn as a ring of the orbits picker.
@Freezed()
sealed class OrbitRing with _$OrbitRing {
  const factory({
    required String providerID,
    required String modelID,
    required String name,

    /// The levels the model offers, weakest first; empty for a model without
    /// effort levels.
    required List<OrbitLevel> levels,

    /// The model's fast mode, or null when it has none.
    required FastModeSupport? fastMode,
  }) = _OrbitRing;
}

/// The orbits picker's content for a catalog whose models share one effort
/// ladder: which models get a ring, which levels get a ray, and what is
/// selected now.
@Freezed()
sealed class ModelOrbits with _$ModelOrbits {
  const factory({
    /// The rings in catalog order, outermost first. Always holds [current].
    required List<OrbitRing> rings,

    /// The ladder levels any ring offers, weakest first.
    required List<EffortLevel> levels,

    /// How many models the catalog offers, so the picker can offer the rest
    /// when there are more than [rings].
    required int totalModels,

    /// Whether every ring's model has fast mode, so the picker need not tag
    /// the ones that do.
    required bool allRingsFast,

    /// The selected model's ring.
    required OrbitRing current,

    /// The selected level, or null when [current] offers no levels.
    required EffortLevel? currentLevel,
  }) = _ModelOrbits;
}
