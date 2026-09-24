import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/claude_backend_catalog_dto.dart";
import "../models/claude_agent_selection.dart";
import "../models/claude_effort_level.dart";

final class const ClaudeBackendCatalog({
  required final List<PluginAgent> agents,
  required final PluginProvidersResult providers,
  required final List<PluginCommand> commands,

  /// Picker id per API-reported model token. Includes catalog
  /// `resolvedModel` values and short family/context aliases such as
  /// `fable[1m]`.
  required final Map<String, String> modelIdsByApiModel,
}) {
  /// The picker id behind an API model name, or null when the catalog has no
  /// such model. Claude can omit a context suffix from a resolved name, so a
  /// bare match takes the first entry sharing the name.
  String? catalogModelId({required String apiModel}) {
    if (modelIdsByApiModel[apiModel] case final id?) return id;
    final bare = _bareModel(apiModel);
    for (final entry in modelIdsByApiModel.entries) {
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
  static const String _defaultModelFamily = "opus";

  /// The families Claude ids carry, used to recognize a model's family and to
  /// build its short alias. Picker order comes from [CatalogStrengthOrder].
  static const List<String> _families = ["fable", "opus", "sonnet", "haiku"];
  static const ClaudeEffortLevel _defaultEffort = ClaudeEffortLevel.high;

  /// Claude's native `/fast` toggle is not offered: the session's fast-mode
  /// selection owns that setting, and the process state it tracks would drift.
  static const String fastModeCommand = "fast";

  /// Claude keeps a prompt cache for about 60 minutes (maintainer-provided).
  static const int _promptCacheTtlSeconds = 60 * 60;

  ClaudeBackendCatalog map({required Map<String, Object?> handshake}) {
    final dto = ClaudeBackendCatalogDto.fromJson(handshake);
    final fastMode = _fastMode(disabledReason: dto.fastModeDisabledReason);
    final models = CatalogStrengthOrder.models(
      [for (final model in dto.models) ?_model(model, fastMode: fastMode)],
      idOf: (model) => model.id,
    );
    final defaultModel =
        models.where((model) => _family(modelId: model.id) == _defaultModelFamily).firstOrNull ?? models.firstOrNull;
    final agentModel = defaultModel == null
        ? null
        : PluginAgentModel(
            modelID: defaultModel.id,
            providerID: providerId,
            variant: defaultModel.defaultVariant,
          );

    return ClaudeBackendCatalog(
      // Only the default is advertised: Plan is a harness mode, not an agent.
      agents: List.unmodifiable([
        PluginAgent(
          name: ClaudeAgentSelection.standard.displayName,
          description: ClaudeAgentSelection.standard.description,
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
      modelIdsByApiModel: Map.unmodifiable(_modelIdsByApiModel(dto.models)),
    );
  }

  /// Whether [handshake] masks the account's fast-mode state behind the SDK
  /// opt-in. Claude CLI 2.1.281 checks the opt-in before the account, so a
  /// catalog probe must opt in and re-read the handshake to learn the real
  /// reason (verified live: `extra_usage_disabled` only appears after opting in).
  bool fastModeNeedsOptIn({required Map<String, Object?> handshake}) {
    final dto = ClaudeBackendCatalogDto.fromJson(handshake);
    return dto.fastModeDisabledReason == _sdkOptInRequired &&
        dto.models.any((model) => model.supportsFastMode ?? false);
  }

  static const String _sdkOptInRequired = "sdk_opt_in_required";

  /// The account-level fast mode every fast-capable model shares.
  PluginFastModeSupport _fastMode({required String? disabledReason}) {
    final reason = switch (disabledReason) {
      // Still masked only when the probe's opt-in failed. Prompts opt in
      // through apply_flag_settings, so fast mode stays offered.
      null || _sdkOptInRequired => null,
      // Transient states say nothing about the account. Offering fast mode is
      // less misleading than a disabled control that recovers on its own.
      final String transient && ("network_error" || "pending") => _transientFastModeReason(raw: transient),
      "extra_usage_disabled" => PluginFastModeUnavailableReason.extraUsageDisabled,
      // The CLI's message: "Fast mode requires a paid subscription".
      "free" => PluginFastModeUnavailableReason.notOnPlan,
      // An organization policy turned fast mode off, or excludes its model.
      "preference" || "model_not_allowed" => PluginFastModeUnavailableReason.disabledByOrganization,
      // A non-Anthropic API provider, an environment override, or a remote kill switch.
      "not_first_party" || "disabled_by_env" || "unknown" => PluginFastModeUnavailableReason.unknown,
      final unmapped => _unmappedFastModeReason(raw: unmapped),
    };
    return reason == null
        ? const PluginFastModeSupport.available(promptCacheTtlSeconds: _promptCacheTtlSeconds)
        : PluginFastModeSupport.unavailable(reason: reason);
  }

  PluginFastModeUnavailableReason? _transientFastModeReason({required String raw}) {
    Log.w("[claude] fast mode offered while its availability is transiently unknown: $raw");
    return null;
  }

  PluginFastModeUnavailableReason _unmappedFastModeReason({required String raw}) {
    Log.w("[claude] fast mode unavailable for an unmapped reason: $raw");
    return PluginFastModeUnavailableReason.unknown;
  }

  Map<String, String> _modelIdsByApiModel(List<ClaudeModelDto> models) {
    final mappedModels = [
      for (final dto in models)
        if (_model(dto, fastMode: null) case final model?) (dto: dto, model: model),
    ];
    final ids = <String, String>{};
    for (final entry in mappedModels) {
      if (entry.dto.resolvedModel?.trim() case final resolved? when resolved.isNotEmpty) {
        ids[resolved] = entry.model.id;
      }
    }
    for (final entry in mappedModels) {
      if (_familyAlias(modelId: entry.model.id) case final alias?) {
        ids.putIfAbsent(alias, () => entry.model.id);
      }
    }
    return ids;
  }

  String? _family({required String modelId}) {
    final bare = ClaudeBackendCatalog._bareModel(modelId);
    for (final family in _families) {
      if (bare == family || bare.startsWith("$family-") || bare.contains("-$family-") || bare.endsWith("-$family")) {
        return family;
      }
    }
    return null;
  }

  String? _familyAlias({required String modelId}) {
    final family = _family(modelId: modelId);
    if (family == null) return null;
    final bare = ClaudeBackendCatalog._bareModel(modelId);
    return "$family${modelId.substring(bare.length)}";
  }

  PluginModel? _model(ClaudeModelDto dto, {required PluginFastModeSupport? fastMode}) {
    final id = dto.value?.trim();
    if (id == null || id.isEmpty || id == _cliDefaultModelId) return null;
    final displayName = dto.displayName?.trim();
    final resolvedModel = dto.resolvedModel?.trim();
    final variants = dto.supportsEffort ?? false
        ? CatalogStrengthOrder.variants({
            for (final raw in dto.supportedEffortLevels) ?ClaudeEffortLevel.tryParse(raw)?.wireValue,
          })
        : <String>[];
    return PluginModel(
      fastMode: dto.supportsFastMode ?? false ? fastMode : null,
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
    if (name == null || name.isEmpty || name == fastModeCommand) return null;
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
