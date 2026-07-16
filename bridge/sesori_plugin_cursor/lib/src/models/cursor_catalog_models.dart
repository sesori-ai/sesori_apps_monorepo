/// One selectable Cursor config option.
class CursorCatalogOption {
  const CursorCatalogOption({
    required this.value,
    required this.name,
    required this.description,
  });

  final String value;
  final String name;
  final String? description;
}

/// The thought-level selector exposed for one loaded model.
class CursorThoughtLevelSnapshot {
  CursorThoughtLevelSnapshot({
    required this.configId,
    required List<String> variants,
    required this.defaultValue,
  }) : variants = List.unmodifiable(variants);

  final String configId;
  final List<String> variants;
  final String? defaultValue;
}

/// Typed Cursor catalog data parsed from an ACP session result.
class CursorCatalogSnapshot {
  CursorCatalogSnapshot({
    required this.modelConfigId,
    required List<CursorCatalogOption> models,
    required this.loadedModelId,
    required this.modeConfigId,
    required List<CursorCatalogOption> modes,
    required this.loadedModeId,
    required this.thoughtLevel,
  }) : models = List.unmodifiable(models),
       modes = List.unmodifiable(modes);

  final String? modelConfigId;
  final List<CursorCatalogOption> models;
  final String? loadedModelId;
  final String? modeConfigId;
  final List<CursorCatalogOption> modes;
  final String? loadedModeId;
  final CursorThoughtLevelSnapshot? thoughtLevel;
}

/// Existing session that can be loaded to discover Cursor's catalog.
class CursorCatalogCandidate {
  const CursorCatalogCandidate({
    required this.sessionId,
    required this.cwd,
    required this.updatedAtMs,
  });

  final String sessionId;
  final String cwd;
  final int? updatedAtMs;
}

/// Deduplicated candidates plus whether all requested enumerations succeeded.
class CursorCatalogCandidateListResult {
  CursorCatalogCandidateListResult({
    required List<CursorCatalogCandidate> candidates,
    required this.exhaustive,
  }) : candidates = List.unmodifiable(candidates);

  final List<CursorCatalogCandidate> candidates;
  final bool exhaustive;
}

/// Catalog values needed by the plugin after a session capture is applied.
class CursorCatalogCaptureResult {
  const CursorCatalogCaptureResult({required this.loadedModelId});

  final String? loadedModelId;
}

enum CursorCatalogProbeOutcome { complete, exhausted, retryableFailure }
