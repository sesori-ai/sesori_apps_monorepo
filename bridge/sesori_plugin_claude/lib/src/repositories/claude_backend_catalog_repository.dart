import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/claude_backend_catalog_dto.dart";
import "../models/claude_agent_selection.dart";
import "../models/claude_effort_level.dart";

final class const ClaudeBackendCatalog({
  required final List<PluginAgent> agents,
  required final PluginProvidersResult providers,
  required final List<PluginCommand> commands,

  /// Picker id per catalog `resolvedModel` (`claude-opus-5[1m]` → `opus[1m]`).
  required final Map<String, String> modelIdsByResolvedModel,
}) {
  /// The picker id behind an API model name, or null when the catalog has no
  /// such model. The stream reports `claude-opus-5` for both `opus` and
  /// `opus[1m]`, so a bare match takes the first entry sharing the name.
  String? catalogModelId({required String apiModel}) {
    if (modelIdsByResolvedModel[apiModel] case final id?) return id;
    final bare = _bareModel(apiModel);
    for (final entry in modelIdsByResolvedModel.entries) {
      if (_bareModel(entry.key) == bare) return entry.value;
    }
    return null;
  }

  static String _bareModel(String model) => model.replaceFirst(RegExp(r"\[[^\]]*\]$"), "");
}

/// Maps Claude's backend catalog into the backend-neutral plugin contract.
final class const ClaudeBackendCatalogRepository() {
  static const String providerId = "anthropic";

  /// Claude's own catalog entry that resolves to whichever model and effort the
  /// CLI configuration currently prefers. It is dropped rather than surfaced:
  /// a picker entry named "Default" tells the user nothing about what will run.
  static const String _cliDefaultModelId = "default";

  /// Sesori's default selection, named explicitly in place of [_cliDefaultModelId].
  static const String _defaultModelIdPrefix = "opus";
  static const ClaudeEffortLevel _defaultEffort = ClaudeEffortLevel.high;

  /// Model families strongest first, as the picker lists them. The CLI's own
  /// order is kept within a family and for families not listed here, which
  /// follow the known ones.
  static const List<String> _familiesByStrength = ["fable", "opus", "sonnet", "haiku"];

  ClaudeBackendCatalog map({required Map<String, Object?> handshake}) {
    final dto = ClaudeBackendCatalogDto.fromJson(handshake);
    final unranked = [
      for (final model in dto.models) ?_model(model),
    ];
    final models = [
      for (final family in _familiesByStrength) ...unranked.where((model) => model.id.startsWith(family)),
      ...unranked.where((model) => !_familiesByStrength.any(model.id.startsWith)),
    ];
    final defaultModel =
        models.where((model) => model.id.startsWith(_defaultModelIdPrefix)).firstOrNull ?? models.firstOrNull;
    final agentModel = defaultModel == null
        ? null
        : PluginAgentModel(
            modelID: defaultModel.id,
            providerID: providerId,
            variant: defaultModel.defaultVariant,
          );

    return ClaudeBackendCatalog(
      agents: List.unmodifiable([
        for (final selection in ClaudeAgentSelection.values)
          PluginAgent(
            name: selection.displayName,
            description: selection.description,
            model: agentModel,
            mode: PluginAgentMode.primary,
            hidden: false,
          ),
      ]),
      providers: PluginProvidersResult(
        providers: models.isEmpty
            ? const []
            : [
                PluginProvider(
                  id: providerId,
                  name: "Anthropic",
                  authType: PluginProviderAuthType.oauth,
                  models: models,
                  defaultModelID: defaultModel?.id,
                ),
              ],
      ),
      commands: List.unmodifiable([
        for (final command in dto.commands) ?_command(command),
      ]),
      modelIdsByResolvedModel: Map.unmodifiable({
        for (final model in dto.models)
          if (_model(model) case final mapped? when model.resolvedModel?.trim().isNotEmpty ?? false)
            model.resolvedModel!.trim(): mapped.id,
      }),
    );
  }

  PluginModel? _model(ClaudeModelDto dto) {
    final id = dto.value?.trim();
    if (id == null || id.isEmpty || id == _cliDefaultModelId) return null;
    final displayName = dto.displayName?.trim();
    final resolvedModel = dto.resolvedModel?.trim();
    final supported = {
      for (final raw in dto.supportedEffortLevels) ?ClaudeEffortLevel.tryParse(raw),
    };
    // Strongest first, as the picker lists them.
    final variants = dto.supportsEffort ?? false
        ? [
            for (final level in ClaudeEffortLevel.values.reversed)
              if (supported.contains(level)) level.wireValue,
          ]
        : <String>[];
    return PluginModel(
      id: id,
      name: displayName?.isNotEmpty ?? false
          ? displayName!
          : resolvedModel?.isNotEmpty ?? false
          ? resolvedModel!
          : id,
      variants: variants,
      defaultVariant: variants.contains(_defaultEffort.wireValue) ? _defaultEffort.wireValue : null,
      family: null,
      isAvailable: true,
      releaseDate: null,
    );
  }

  PluginCommand? _command(ClaudeCommandDto dto) {
    final name = dto.name?.trim();
    if (name == null || name.isEmpty) return null;
    final description = dto.description?.trim();
    final hint = dto.argumentHint?.trim();
    return PluginCommand(
      name: name,
      description: description?.isNotEmpty ?? false ? description : null,
      hints: [if (hint?.isNotEmpty ?? false) hint!],
      provider: null,
      source: PluginCommandSource.command,
    );
  }
}
