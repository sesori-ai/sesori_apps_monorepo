/// One selectable Cursor config option.
class const CursorCatalogOption({
    required final String value,
    required final String name,
    required final String? description,
  });

/// The thought-level selector exposed for one loaded model.
class CursorThoughtLevelSnapshot({
    required final String configId,
    required List<String> variants,
    required final String? defaultValue,
  }) {

  final List<String> variants = List.unmodifiable(variants);
}

/// Cursor's stable execution modes, available before the first session exists.
enum CursorMode({required final String id, required final String displayName}) {
  agent(id: "agent", displayName: "Agent"),
  plan(id: "plan", displayName: "Plan"),
  ask(id: "ask", displayName: "Ask");

}

/// Account catalog returned without creating or loading a Cursor session.
class CursorCatalogBootstrapSnapshot({
    required List<CursorCatalogOption> models,
    required List<CursorCatalogOption> modes,
    required final String defaultModeId,
    required Map<String, CursorThoughtLevelSnapshot> thoughtLevelsByModel,
  }) {

  final List<CursorCatalogOption> models = List.unmodifiable(models);
  final List<CursorCatalogOption> modes = List.unmodifiable(modes);
  final Map<String, CursorThoughtLevelSnapshot> thoughtLevelsByModel = Map.unmodifiable(thoughtLevelsByModel);
}

/// Typed Cursor catalog data parsed from an ACP session result.
class CursorCatalogSnapshot({
    required final String? modelConfigId,
    required List<CursorCatalogOption> models,
    required final String? loadedModelId,
    required final String? modeConfigId,
    required List<CursorCatalogOption> modes,
    required final String? loadedModeId,
    required final CursorThoughtLevelSnapshot? thoughtLevel,
  }) {

  final List<CursorCatalogOption> models = List.unmodifiable(models);
  final List<CursorCatalogOption> modes = List.unmodifiable(modes);
}

/// Existing session that can be loaded to discover Cursor's catalog.
class const CursorCatalogCandidate({
    required final String sessionId,
    required final String cwd,
    required final int? updatedAtMs,
  });

/// Deduplicated candidates plus whether all requested enumerations succeeded.
class CursorCatalogCandidateListResult({
    required List<CursorCatalogCandidate> candidates,
    required final bool exhaustive,
  }) {

  final List<CursorCatalogCandidate> candidates = List.unmodifiable(candidates);
}

/// Catalog values needed by the plugin after a session capture is applied.
class const CursorCatalogCaptureResult({required final String? loadedModelId});

enum CursorCatalogProbeOutcome() { complete, exhausted, retryableFailure }
