import "../models/sesori/agent_info.dart";
import "../models/sesori/agent_mode.dart";
import "../models/sesori/provider_info.dart";
import "../models/sesori/session_variant.dart";

/// How an agent, model, variant and fast-mode selection is checked against
/// the catalog a backend currently advertises.
///
/// One owner for both sides: the app reconciles what is on screen with these
/// rules, and the bridge corrects the remembered selection of a prompt it
/// sends itself the same way, so the two cannot drift apart.
///
/// Pure and stateless: it reads a catalog and returns a value, and never
/// emits, persists, or calls a backend.
class const SessionOptionsCatalogCalculator() {
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

  /// The effort/thinking variants [model] offers, in the order the plugin
  /// declared them. `"none"` is a backend spelling of "no variant", never a
  /// picker entry.
  ///
  /// A model the catalog does not offer has no known variants, so it offers
  /// only the one it carries: a session kept on its own unlisted model still
  /// shows the effort it recorded, and nothing else.
  List<SessionVariant> availableVariants({
    required List<ProviderInfo> providers,
    required AgentModel? model,
  }) {
    if (model == null) return const [];
    final providerModel = _providerModel(providers: providers, model: model);
    if (providerModel == null || !providerModel.isAvailable) {
      final carried = model.variant;
      return carried == null || carried == "none" ? const [] : [SessionVariant(id: carried)];
    }
    return providerModel.variants
        .where((variant) => variant != "none")
        .map((variant) => SessionVariant(id: variant))
        .toList(growable: false);
  }

  /// The variant [model] runs at when none was chosen: the plugin's declared
  /// default when the model offers it, otherwise the first it offers, or null
  /// when it offers none.
  String? defaultVariant({
    required List<ProviderInfo> providers,
    required AgentModel? model,
  }) {
    if (model == null) return null;
    final variants = availableVariants(providers: providers, model: model);
    final declared = _providerModel(providers: providers, model: model)?.defaultVariant;
    return variants.any((variant) => variant.id == declared) ? declared : variants.firstOrNull?.id;
  }

  /// [model] with its variant resolved: a model that offers variants always
  /// runs at a named one, so an unset or withdrawn variant resolves to
  /// [defaultVariant].
  AgentModel? withResolvedVariant({
    required List<ProviderInfo> providers,
    required AgentModel? model,
  }) {
    if (model == null) return null;
    final variants = availableVariants(providers: providers, model: model);
    if (variants.any((variant) => variant.id == model.variant)) return model;
    return model.copyWith(
      variant: defaultVariant(providers: providers, model: model),
    );
  }

  /// The fast mode [model] offers, or null when it has none or the catalog no
  /// longer offers the model.
  FastModeSupport? fastModeSupport({
    required List<ProviderInfo> providers,
    required AgentModel? model,
  }) {
    if (model == null) return null;
    final providerModel = _providerModel(providers: providers, model: model);
    if (providerModel == null || !providerModel.isAvailable) return null;
    return providerModel.fastMode;
  }

  /// Whether [model] runs in fast mode given the user's [requested] choice:
  /// only while the model's fast mode is available, otherwise off.
  bool resolvedFastMode({
    required List<ProviderInfo> providers,
    required AgentModel? model,
    required bool requested,
  }) {
    return requested && fastModeSupport(providers: providers, model: model) is FastModeAvailable;
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
    return candidates
            .where((candidate) => candidate != null && selectable.any((agent) => agent.name == candidate))
            .firstOrNull ??
        selectable.firstOrNull?.name;
  }

  ProviderModel? _providerModel({
    required List<ProviderInfo> providers,
    required AgentModel model,
  }) {
    return providers.where((provider) => provider.id == model.providerID).firstOrNull?.models[model.modelID];
  }
}
