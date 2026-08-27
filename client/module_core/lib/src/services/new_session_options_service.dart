import "package:collection/collection.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/models/session_options/session_options_request_mode.dart";
import "../logging/logging.dart";
import "../repositories/models/session_options_repository_result.dart";
import "../repositories/session_repository.dart";
import "../utils/model_filter/default_model_selector.dart";
import "models/new_session_options_source.dart";
import "models/new_session_selection_intent.dart";

part "new_session_options_service.freezed.dart";

@Freezed()
sealed class NewSessionOptionsData with _$NewSessionOptionsData {
  const factory({
    required List<AgentInfo> agents,
    required List<ProviderInfo> providers,
    required List<CommandInfo> commands,
    required String? selectedAgent,
    required AgentModel? selectedAgentModel,
    required CommandInfo? stagedCommand,
    required List<SessionVariant> availableVariants,
  }) = _NewSessionOptionsData;
}

sealed class const NewSessionOptionsLoadResult();

/// What asked for a load: the screen opening or reconnecting, the user pressing
/// refresh, or a stale-reported cache being brought up to date in the
/// background. A silent refresh reaches the bridge as a forced one; the
/// distinction is that nobody is waiting on it, so it must not overwrite what
/// the user does while it runs.
enum NewSessionOptionsLoadMode() { dynamicLoad, forcedRefresh, silentRefresh }

/// Loaded options, and whether the bridge served them from a snapshot old
/// enough to be worth refreshing behind the user's back. Only a cache the
/// bridge chose not to rediscover is stale; anything just discovered is not.
final class const NewSessionOptionsLoaded({
    required final NewSessionOptionsData options,
    required final NewSessionOptionsSource source,
    required final bool isStale,
  }) extends NewSessionOptionsLoadResult;

final class const NewSessionOptionsUnsupported() extends NewSessionOptionsLoadResult;

final class const NewSessionOptionsUnavailable() extends NewSessionOptionsLoadResult;

final class const NewSessionOptionsLoadFailureUnavailable() extends NewSessionOptionsLoadResult;

final class const NewSessionOptionsFailureRetained({required final NewSessionOptionsData options, required final NewSessionOptionsSource source}) extends NewSessionOptionsLoadResult;

final class const NewSessionOptionsFailureUnavailable({required final ApiError error, required final NewSessionOptionsSource source}) extends NewSessionOptionsLoadResult;

final class const NewSessionOptionsRefreshFailureUnavailable() extends NewSessionOptionsLoadResult;

@lazySingleton
class NewSessionOptionsService({
    required final SessionRepository _sessionRepository,
    required final DefaultModelSelector _defaultModelSelector,
  }) {
  Future<NewSessionOptionsLoadResult> load({
    required String projectId,
    required String pluginId,
    required NewSessionOptionsSource source,
    required NewSessionOptionsLoadMode mode,
    required NewSessionSelectionIntent? restoredSelection,
    required NewSessionOptionsData? previousOptions,
  }) async {
    if (source == NewSessionOptionsSource.legacy) {
      if (mode == NewSessionOptionsLoadMode.dynamicLoad) {
        return previousOptions == null
            ? const NewSessionOptionsUnsupported()
            : NewSessionOptionsLoaded(
                options: previousOptions,
                source: NewSessionOptionsSource.legacy,
                isStale: false,
              );
      }
      return await _loadLegacy(
        projectId: projectId,
        pluginId: pluginId,
        restoredSelection: restoredSelection,
        previousOptions: previousOptions,
      );
    }

    final result = await _sessionRepository.loadSessionOptions(
      projectId: projectId,
      pluginId: pluginId,
      mode: switch (mode) {
        NewSessionOptionsLoadMode.dynamicLoad => SessionOptionsRequestMode.dynamic,
        NewSessionOptionsLoadMode.forcedRefresh ||
        NewSessionOptionsLoadMode.silentRefresh => SessionOptionsRequestMode.forceRefresh,
      },
    );
    return switch (result) {
      SessionOptionsRepositoryAvailable(:final catalog, :final isStale) => NewSessionOptionsLoaded(
        options: _resolve(
          catalog: catalog,
          restoredSelection: restoredSelection,
          previousOptions: previousOptions,
        ),
        source: NewSessionOptionsSource.aggregate,
        isStale: isStale,
      ),
      SessionOptionsRepositoryUnsupported() => const NewSessionOptionsUnsupported(),
      SessionOptionsRepositoryCacheUnavailable() => const NewSessionOptionsUnavailable(),
      SessionOptionsRepositoryProjectNotFound(:final error) => NewSessionOptionsFailureUnavailable(
        error: error,
        source: NewSessionOptionsSource.aggregate,
      ),
      SessionOptionsRepositoryRefreshFailedRetained() =>
        previousOptions == null
            ? const NewSessionOptionsRefreshFailureUnavailable()
            : NewSessionOptionsFailureRetained(
                options: previousOptions,
                source: NewSessionOptionsSource.aggregate,
              ),
      SessionOptionsRepositoryRefreshFailedUnavailable() => switch (mode) {
        NewSessionOptionsLoadMode.dynamicLoad => const NewSessionOptionsLoadFailureUnavailable(),
        NewSessionOptionsLoadMode.forcedRefresh => const NewSessionOptionsRefreshFailureUnavailable(),
        // A refresh nobody asked for must not take working options away. The
        // bridge served these moments ago, so the honest answer is that the
        // update failed, not that there is nothing left to choose from.
        NewSessionOptionsLoadMode.silentRefresh => previousOptions == null
            ? const NewSessionOptionsRefreshFailureUnavailable()
            : NewSessionOptionsFailureRetained(
                options: previousOptions,
                source: NewSessionOptionsSource.aggregate,
              ),
      },
      SessionOptionsRepositoryFailure(:final error) => _transientFailure(
        error: error,
        source: NewSessionOptionsSource.aggregate,
        previousOptions: previousOptions,
      ),
    };
  }

  Future<NewSessionOptionsLoadResult> _loadLegacy({
    required String projectId,
    required String pluginId,
    required NewSessionSelectionIntent? restoredSelection,
    required NewSessionOptionsData? previousOptions,
  }) async {
    final result = await _sessionRepository.loadLegacySessionOptions(projectId: projectId, pluginId: pluginId);
    switch (result) {
      case LegacySessionOptionsRepositoryAvailable(:final catalog):
        return NewSessionOptionsLoaded(
          options: _resolve(
            catalog: catalog,
            restoredSelection: restoredSelection,
            previousOptions: previousOptions,
          ),
          source: NewSessionOptionsSource.legacy,
          isStale: false,
        );
      case LegacySessionOptionsRepositoryPartial(:final catalog, :final errors):
        _logLegacyErrors(errors);
        final failedSources = errors.map((failure) => failure.source).toSet();
        final retainedCatalog = previousOptions == null
            ? catalog
            : SessionOptionsCatalog(
                agents: failedSources.contains(LegacySessionOptionSource.agents)
                    ? previousOptions.agents
                    : catalog.agents,
                providers: failedSources.contains(LegacySessionOptionSource.providers)
                    ? previousOptions.providers
                    : catalog.providers,
                providersConnectedOnly: catalog.providersConnectedOnly,
                commands: failedSources.contains(LegacySessionOptionSource.commands)
                    ? previousOptions.commands
                    : catalog.commands,
                lastUsedPromptDefaults: null,
              );
        return NewSessionOptionsLoaded(
          options: _resolve(
            catalog: retainedCatalog,
            restoredSelection: restoredSelection,
            previousOptions: previousOptions,
          ),
          source: NewSessionOptionsSource.legacy,
          isStale: false,
        );
      case LegacySessionOptionsRepositoryFailure(:final errors):
        _logLegacyErrors(errors);
        return _transientFailure(
          error: errors.first.error,
          source: NewSessionOptionsSource.legacy,
          previousOptions: previousOptions,
        );
    }
  }

  void _logLegacyErrors(List<LegacySessionOptionError> errors) {
    for (final failure in errors) {
      loge("Failed to load legacy ${failure.source.name}", failure.error);
    }
  }

  NewSessionOptionsLoadResult _transientFailure({
    required ApiError error,
    required NewSessionOptionsSource source,
    required NewSessionOptionsData? previousOptions,
  }) => previousOptions == null
      ? NewSessionOptionsFailureUnavailable(error: error, source: source)
      : NewSessionOptionsFailureRetained(options: previousOptions, source: source);

  NewSessionOptionsData _resolve({
    required SessionOptionsCatalog catalog,
    required NewSessionSelectionIntent? restoredSelection,
    required NewSessionOptionsData? previousOptions,
  }) {
    final agents = catalog.agents
        .where((agent) => !agent.hidden && agent.mode != AgentMode.subagent)
        .toList(growable: false);
    final providers = catalog.providers;
    final commands = catalog.commands;
    final effectiveSelection = _mergeSelection(
      restoredSelection: restoredSelection,
      lastUsedPromptDefaults: catalog.lastUsedPromptDefaults,
    );

    final defaultAgent = agents.firstOrNull?.name;
    final restoredAgent = effectiveSelection?.agentName;
    final selectedAgent = restoredAgent != null && agents.any((agent) => agent.name == restoredAgent)
        ? restoredAgent
        : defaultAgent;
    final selectedAgentInfo = selectedAgent == null
        ? null
        : agents.firstWhereOrNull((agent) => agent.name == selectedAgent);
    final defaultAgentModel =
        _validatedModel(
          providers: providers,
          model: selectedAgentInfo?.model,
        ) ??
        _pickDefaultModel(providers: providers);

    final restoredModel = effectiveSelection?.model;
    final validatedRestoredModel = _validatedModel(
      providers: providers,
      model: restoredModel == null
          ? null
          : AgentModel(
              providerID: restoredModel.providerId,
              modelID: restoredModel.modelId,
              variant: null,
            ),
    );
    final selectedAgentModel = _applyVariantIntent(
      providers: providers,
      model: validatedRestoredModel ?? defaultAgentModel,
      variantIntent: restoredModel == null || validatedRestoredModel != null
          ? effectiveSelection?.variant
          : null,
    );
    final stagedCommandName = previousOptions?.stagedCommand?.name;
    final stagedCommand = stagedCommandName == null
        ? null
        : commands.firstWhereOrNull((command) => command.name == stagedCommandName);

    return NewSessionOptionsData(
      agents: agents,
      providers: providers,
      commands: commands,
      selectedAgent: selectedAgent,
      selectedAgentModel: selectedAgentModel,
      stagedCommand: stagedCommand,
      availableVariants: availableVariants(providers: providers, model: selectedAgentModel),
    );
  }

  NewSessionSelectionIntent? _mergeSelection({
    required NewSessionSelectionIntent? restoredSelection,
    required SessionPromptDefaults? lastUsedPromptDefaults,
  }) {
    final rememberedModel = lastUsedPromptDefaults?.model;
    final rememberedVariant = rememberedModel?.variant;
    final remembered = lastUsedPromptDefaults == null
        ? null
        : NewSessionSelectionIntent(
            agentName: lastUsedPromptDefaults.agent,
            model: rememberedModel == null
                ? null
                : NewSessionModelIntent(
                    providerId: rememberedModel.providerID,
                    modelId: rememberedModel.modelID,
                  ),
            variant: rememberedVariant == null ? null : NewSessionVariantIntent(id: rememberedVariant),
          );
    if (restoredSelection == null) return remembered;
    return NewSessionSelectionIntent(
      agentName: restoredSelection.agentName ?? remembered?.agentName,
      model: restoredSelection.model ?? remembered?.model,
      variant: restoredSelection.variant ?? remembered?.variant,
    );
  }

  AgentModel? _applyVariantIntent({
    required List<ProviderInfo> providers,
    required AgentModel? model,
    required NewSessionVariantIntent? variantIntent,
  }) {
    if (model == null || variantIntent == null) return model;
    final id = variantIntent.id;
    return availableVariants(providers: providers, model: model).any((variant) => variant.id == id)
        ? model.copyWith(variant: id)
        : model;
  }

  NewSessionOptionsData? selectAgent({
    required NewSessionOptionsData options,
    required String agent,
    required NewSessionSelectionIntent? selectionIntent,
  }) {
    final agentInfo = options.agents.firstWhereOrNull((item) => item.name == agent);
    if (agentInfo == null) return null;
    final modelIntent = selectionIntent?.model;
    final selectedAgentModel = _applyVariantIntent(
      providers: options.providers,
      model:
          _validatedModel(
            providers: options.providers,
            model: modelIntent == null
                ? null
                : AgentModel(providerID: modelIntent.providerId, modelID: modelIntent.modelId, variant: null),
          ) ??
          _validatedModel(providers: options.providers, model: agentInfo.model) ??
          options.selectedAgentModel,
      variantIntent: selectionIntent?.variant,
    );
    return NewSessionOptionsData(
      agents: options.agents,
      providers: options.providers,
      commands: options.commands,
      selectedAgent: agent,
      selectedAgentModel: selectedAgentModel,
      stagedCommand: options.stagedCommand,
      availableVariants: availableVariants(providers: options.providers, model: selectedAgentModel),
    );
  }

  NewSessionOptionsData? selectModel({
    required NewSessionOptionsData options,
    required String providerId,
    required String modelId,
    required NewSessionVariantIntent? variantIntent,
  }) {
    final requested = AgentModel(providerID: providerId, modelID: modelId, variant: null);
    if (_validatedModel(providers: options.providers, model: requested) == null) return null;

    final agentModel = options.agents
        .firstWhereOrNull(
          (agent) => agent.model?.providerID == providerId && agent.model?.modelID == modelId,
        )
        ?.model;
    final variants = availableVariants(providers: options.providers, model: requested);
    final previousVariant = options.selectedAgentModel?.variant;
    final agentVariant = agentModel?.variant;
    final selectedVariant = previousVariant != null && variants.any((variant) => variant.id == previousVariant)
        ? previousVariant
        : agentVariant != null && variants.any((variant) => variant.id == agentVariant)
        ? agentVariant
        : variants.firstOrNull?.id;
    final selectedAgentModel = _applyVariantIntent(
      providers: options.providers,
      model: requested.copyWith(variant: selectedVariant),
      variantIntent: variantIntent,
    );

    return NewSessionOptionsData(
      agents: options.agents,
      providers: options.providers,
      commands: options.commands,
      selectedAgent: options.selectedAgent,
      selectedAgentModel: selectedAgentModel,
      stagedCommand: options.stagedCommand,
      availableVariants: variants,
    );
  }

  NewSessionOptionsData? selectVariant({
    required NewSessionOptionsData options,
    required SessionVariant variant,
  }) {
    final model = options.selectedAgentModel;
    if (model == null) return null;
    if (!options.availableVariants.any((available) => available.id == variant.id)) return null;
    return NewSessionOptionsData(
      agents: options.agents,
      providers: options.providers,
      commands: options.commands,
      selectedAgent: options.selectedAgent,
      selectedAgentModel: model.copyWith(variant: variant.id),
      stagedCommand: options.stagedCommand,
      availableVariants: options.availableVariants,
    );
  }

  NewSessionOptionsData? stageCommand({
    required NewSessionOptionsData options,
    required CommandInfo command,
  }) {
    final available = options.commands.firstWhereOrNull((item) => item == command);
    if (available == null) return null;
    return NewSessionOptionsData(
      agents: options.agents,
      providers: options.providers,
      commands: options.commands,
      selectedAgent: options.selectedAgent,
      selectedAgentModel: options.selectedAgentModel,
      stagedCommand: available,
      availableVariants: options.availableVariants,
    );
  }

  NewSessionOptionsData clearStagedCommand({required NewSessionOptionsData options}) {
    return NewSessionOptionsData(
      agents: options.agents,
      providers: options.providers,
      commands: options.commands,
      selectedAgent: options.selectedAgent,
      selectedAgentModel: options.selectedAgentModel,
      stagedCommand: null,
      availableVariants: options.availableVariants,
    );
  }

  List<SessionVariant> availableVariants({
    required List<ProviderInfo> providers,
    required AgentModel? model,
  }) {
    final providerId = model?.providerID;
    final modelId = model?.modelID;
    if (providerId == null || modelId == null) return const [];
    final providerModel = providers.firstWhereOrNull((provider) => provider.id == providerId)?.models[modelId];
    if (providerModel == null || !providerModel.isAvailable) return const [];
    return providerModel.variants
        .where((variant) => variant != "none")
        .map((variant) => SessionVariant(id: variant))
        .toList(growable: false);
  }

  AgentModel? _validatedModel({required List<ProviderInfo> providers, required AgentModel? model}) {
    if (model == null) return null;
    final providerModel = providers
        .firstWhereOrNull((provider) => provider.id == model.providerID)
        ?.models[model.modelID];
    if (providerModel == null || !providerModel.isAvailable) return null;
    final variants = availableVariants(providers: providers, model: model);
    final variant = model.variant;
    return model.copyWith(
      variant: variants.any((available) => available.id == variant) ? variant : variants.firstOrNull?.id,
    );
  }

  AgentModel? _pickDefaultModel({required List<ProviderInfo> providers}) {
    for (final provider in providers) {
      final model = _defaultModelSelector.pickFromProvider(
        models: provider.models,
        defaultModelID: provider.defaultModelID,
      );
      if (model != null) {
        return _validatedModel(
          providers: providers,
          model: AgentModel(providerID: provider.id, modelID: model.id, variant: null),
        );
      }
    }
    return null;
  }
}
