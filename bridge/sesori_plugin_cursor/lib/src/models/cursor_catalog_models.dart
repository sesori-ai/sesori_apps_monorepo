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

/// Cursor's stable execution modes, available before the first session exists.
enum CursorMode {
  agent(id: "agent", displayName: "Agent"),
  plan(id: "plan", displayName: "Plan"),
  ask(id: "ask", displayName: "Ask");

  const CursorMode({required this.id, required this.displayName});

  final String id;
  final String displayName;
}

/// Account catalog returned without creating or loading a Cursor session.
class CursorCatalogBootstrapSnapshot {
  CursorCatalogBootstrapSnapshot({
    required List<CursorCatalogOption> models,
    required List<CursorCatalogOption> modes,
    required this.defaultModeId,
    required Map<String, CursorThoughtLevelSnapshot> thoughtLevelsByModel,
  }) : models = List.unmodifiable(models),
       modes = List.unmodifiable(modes),
       thoughtLevelsByModel = Map.unmodifiable(thoughtLevelsByModel);

  final List<CursorCatalogOption> models;
  final List<CursorCatalogOption> modes;
  final String defaultModeId;
  final Map<String, CursorThoughtLevelSnapshot> thoughtLevelsByModel;
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
