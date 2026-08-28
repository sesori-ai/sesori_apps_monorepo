class const CopilotCatalogOption({
  required final String value,
  required final String name,
  required final String? description,
});

class CopilotSessionConfigSnapshot({
  required final String? modelConfigId,
  required List<CopilotCatalogOption> models,
  required final String? currentModelValue,
  required final String? modeConfigId,
  required List<CopilotCatalogOption> modes,
  required final String? currentModeValue,
  required final String? thoughtLevelConfigId,
  required List<CopilotCatalogOption> thoughtLevels,
  required final String? currentThoughtLevelValue,
}) {
  final List<CopilotCatalogOption> models = List.unmodifiable(models);
  final List<CopilotCatalogOption> modes = List.unmodifiable(modes);
  final List<CopilotCatalogOption> thoughtLevels = List.unmodifiable(thoughtLevels);
}
