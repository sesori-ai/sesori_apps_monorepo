import "package:sesori_dart_core/sesori_dart_core.dart" show EffortLevel, ModelOrbits, OrbitLevel, OrbitRing;
import "package:sesori_shared/sesori_shared.dart";

const _ladder = [EffortLevel.low, EffortLevel.medium, EffortLevel.high, EffortLevel.xhigh, EffortLevel.max];

OrbitRing orbitRing({
  required String modelID,
  required String name,
  required List<EffortLevel> levels,
  required bool fast,
}) => OrbitRing(
  providerID: "anthropic",
  modelID: modelID,
  name: name,
  levels: [
    for (final level in levels)
      OrbitLevel(
        level: level,
        variant: SessionVariant(id: level.wireId),
      ),
  ],
  fastMode: fast ? const FastModeSupport.available(promptCacheTtlSeconds: 300) : null,
);

/// The round-16 Claude Code catalog: four rings, the outermost first, one of
/// them without levels. Opus is selected at high.
final fable = orbitRing(modelID: "fable", name: "Fable 5.1", levels: _ladder, fast: false);
final opus = orbitRing(modelID: "opus", name: "Opus 5.5", levels: _ladder, fast: true);
final sonnet = orbitRing(
  modelID: "sonnet",
  name: "Sonnet 5.5",
  levels: const [EffortLevel.low, EffortLevel.medium, EffortLevel.high],
  fast: false,
);
final haiku = orbitRing(modelID: "haiku", name: "Haiku 4.5", levels: const [], fast: false);

ModelOrbits claudeOrbits({
  required int totalModels,
  required OrbitRing current,
  required EffortLevel? currentLevel,
}) => ModelOrbits(
  rings: [fable, opus, sonnet, haiku],
  levels: _ladder,
  totalModels: totalModels,
  allRingsFast: false,
  current: current,
  currentLevel: currentLevel,
);
