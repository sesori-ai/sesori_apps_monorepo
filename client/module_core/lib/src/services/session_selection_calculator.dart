import "package:collection/collection.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../utils/model_filter/default_model_selector.dart";

/// A selection that survived reconciliation against a catalog: what the screen
/// may offer, and what stays chosen.
///
/// [availableVariants] always belongs to [model]. Producing the two together is
/// the point of [SessionSelectionCalculator.reconcile] — a caller that emitted
/// a new model while keeping the previous variant list could offer a variant
/// the model does not have.
class const ReconciledSelection({
  required final String? agentName,
  required final AgentModel? model,
  required final List<SessionVariant> availableVariants,
});

/// Resolves an agent/model/variant/command selection against the catalog a
/// backend currently advertises.
///
/// This is the one owner of that policy. It previously existed twice — once for
/// the New Session screen and once inside `SessionDetailCubit` — and the two
/// copies drifted: only one of them honored [ProviderModel.isAvailable]. Every
/// screen now reconciles through [reconcile] so a selection cannot be validated
/// one way in one place and another way elsewhere.
///
/// Pure and stateless: it reads a catalog and returns a selection, and never
/// emits, persists, or calls a backend. Const-constructed by its callers rather
/// than resolved from the container, like the other calculators in this package.
class const SessionSelectionCalculator() {
  static const DefaultModelSelector _defaultModelSelector = DefaultModelSelector();

  /// The agents a user may pick. Hidden agents and sub-agents are backend
  /// bookkeeping, never picker entries.
  List<AgentInfo> selectableAgents({required List<AgentInfo> agents}) {
    return agents.where((agent) => !agent.hidden && agent.mode != AgentMode.subagent).toList(growable: false);
  }

  /// Whether [model] is one the catalog still offers.
  ///
  /// A model the backend marks unavailable counts as absent: it is listed so a
  /// transcript naming it can still be read, not so it can be selected again.
  bool isModelAvailable({required List<ProviderInfo> providers, required AgentModel model}) {
    return _providerModel(providers: providers, model: model)?.isAvailable ?? false;
  }

  /// The effort/thinking variants [model] offers, default-first as the plugin
  /// declared them. `"none"` is a backend spelling of "no variant", never a
  /// picker entry.
  List<SessionVariant> availableVariants({
    required List<ProviderInfo> providers,
    required AgentModel? model,
  }) {
    if (model == null) return const [];
    final providerModel = _providerModel(providers: providers, model: model);
    if (providerModel == null || !providerModel.isAvailable) return const [];
    return providerModel.variants
        .where((variant) => variant != "none")
        .map((variant) => SessionVariant(id: variant))
        .toList(growable: false);
  }

  /// The agent to run, given [candidates] in preference order: the first the
  /// catalog still offers, otherwise the first selectable agent, otherwise null
  /// because there is nothing to select.
  ///
  /// Null candidates are skipped rather than treated as a choice, so a caller
  /// may pass a value it does not have. A caller for which "unset" is itself
  /// meaningful — a queued prompt inheriting the session's agent — must keep
  /// that rule on its own side rather than asking for it here.
  String? validatedAgentName({
    required List<AgentInfo> agents,
    required List<String?> candidates,
  }) {
    final selectable = selectableAgents(agents: agents);
    return candidates.firstWhereOrNull(
          (candidate) => candidate != null && selectable.any((agent) => agent.name == candidate),
        ) ??
        selectable.firstOrNull?.name;
  }

  /// Reconciles a desired selection against the catalog.
  ///
  /// [agents] may be raw or already filtered; it is put through
  /// [selectableAgents] either way.
  ///
  /// [agentNameCandidates] and [modelCandidates] are preference orders: the
  /// first entry the catalog still offers wins. Nulls are skipped, so a caller
  /// can pass a value it may not have without pre-filtering. When no candidate
  /// survives, the agent falls back to the first selectable one and the model to
  /// the chosen agent's declared model, then to the catalog's own default.
  ///
  /// [retainedModel] is adopted without catalog validation when no candidate
  /// survives, and before those fallbacks. The caller vouches for it, so it is
  /// the one way to keep a model the catalog does not currently advertise.
  /// Callers use it for two things: a session's transcript model, which stays
  /// authoritative so an imported session cannot silently resume on a different
  /// provider, and the selection already on screen, which a catalog change
  /// should not yank out from under the user mid-session. Pass null where only
  /// the catalog may decide — a fresh New Session screen, or a queued prompt
  /// being revalidated before dispatch.
  ReconciledSelection reconcile({
    required List<AgentInfo> agents,
    required List<ProviderInfo> providers,
    required List<String?> agentNameCandidates,
    required List<AgentModel?> modelCandidates,
    required AgentModel? retainedModel,
  }) {
    final selectable = selectableAgents(agents: agents);
    final agentName = validatedAgentName(agents: selectable, candidates: agentNameCandidates);

    final declaredModel = agentName == null
        ? null
        : selectable.firstWhereOrNull((agent) => agent.name == agentName)?.model;
    final model =
        modelCandidates.firstWhereOrNull(
          (candidate) => candidate != null && isModelAvailable(providers: providers, model: candidate),
        ) ??
        retainedModel ??
        _firstAvailable(providers: providers, candidates: [declaredModel]) ??
        _catalogDefault(providers: providers);

    final variants = availableVariants(providers: providers, model: model);
    return ReconciledSelection(
      agentName: agentName,
      model: _withResolvedVariant(model: model, availableVariants: variants),
      availableVariants: variants,
    );
  }

  /// The staged command as the current catalog spells it, or null once the
  /// backend stops offering it.
  CommandInfo? resolveStagedCommand({
    required List<CommandInfo> commands,
    required CommandInfo? staged,
  }) {
    if (staged == null) return null;
    return commands.firstWhereOrNull((command) => command.name == staged.name);
  }

  /// A model that offers variants always runs at a named one, so an unset or
  /// withdrawn variant resolves to the first available. Plugins declare them
  /// default-first, making that the plugin's own default.
  AgentModel? _withResolvedVariant({
    required AgentModel? model,
    required List<SessionVariant> availableVariants,
  }) {
    if (model == null) return null;
    if (availableVariants.any((variant) => variant.id == model.variant)) return model;
    return model.copyWith(variant: availableVariants.firstOrNull?.id);
  }

  AgentModel? _firstAvailable({
    required List<ProviderInfo> providers,
    required List<AgentModel?> candidates,
  }) {
    return candidates.firstWhereOrNull(
      (candidate) => candidate != null && isModelAvailable(providers: providers, model: candidate),
    );
  }

  /// Walks every provider: the first may be misconfigured or fully deprecated
  /// and therefore have no selectable model.
  AgentModel? _catalogDefault({required List<ProviderInfo> providers}) {
    for (final provider in providers) {
      final picked = _defaultModelSelector.pickFromProvider(
        models: provider.models,
        defaultModelID: provider.defaultModelID,
      );
      if (picked != null) {
        return AgentModel(providerID: provider.id, modelID: picked.id, variant: null);
      }
    }
    return null;
  }

  ProviderModel? _providerModel({
    required List<ProviderInfo> providers,
    required AgentModel model,
  }) {
    return providers.firstWhereOrNull((provider) => provider.id == model.providerID)?.models[model.modelID];
  }
}
