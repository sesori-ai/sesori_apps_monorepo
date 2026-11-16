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

/// Resolves an agent/model/variant/fast-mode/command selection against the catalog a
/// backend currently advertises.
///
/// This is the one owner of that policy in the app. It previously existed
/// twice — once for the New Session screen and once inside
/// `SessionDetailCubit` — and the two copies drifted: only one of them honored
/// [ProviderModel.isAvailable]. Every screen now reconciles through [reconcile]
/// so a selection cannot be validated one way in one place and another way
/// elsewhere. The per-option rules it builds on come from
/// [SessionOptionsCatalogCalculator], which the bridge shares.
///
/// Pure and stateless: it reads a catalog and returns a selection, and never
/// emits, persists, or calls a backend. Const-constructed by its callers rather
/// than resolved from the container, like the other calculators in this package.
class const SessionSelectionCalculator() extends SessionOptionsCatalogCalculator {
  static const DefaultModelSelector _defaultModelSelector = DefaultModelSelector();

  /// The variant a switch to [model] runs at: the first of [candidates] the
  /// model offers, otherwise [defaultVariant].
  ///
  /// [candidates] is a preference order, typically the variant the user picked
  /// together with the model, then the one the previous model ran at. Nulls
  /// are skipped, so a caller may pass a value it does not have.
  String? switchedModelVariant({
    required List<ProviderInfo> providers,
    required AgentModel model,
    required List<String?> candidates,
  }) {
    final variants = availableVariants(providers: providers, model: model);
    return candidates.firstWhereOrNull(
          (candidate) => candidate != null && variants.any((variant) => variant.id == candidate),
        ) ??
        defaultVariant(providers: providers, model: model);
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
      model: withResolvedVariant(providers: providers, model: model),
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
}
