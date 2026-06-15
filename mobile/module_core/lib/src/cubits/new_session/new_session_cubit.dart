import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/session/session_service.dart";
import "../../errors/api_error_remote_failure_x.dart";
import "../../logging/logging.dart";
import "../../services/new_session_selection_store.dart";
import "../../utils/model_filter/default_model_selector.dart";
import "new_session_state.dart";

class NewSessionCubit extends Cubit<NewSessionState> {
  final SessionService _sessionService;
  final NewSessionSelectionStore _selectionStore;
  final String _projectId;
  static const _defaultModelSelector = DefaultModelSelector();

  NewSessionCubit({
    required SessionService sessionService,
    required NewSessionSelectionStore selectionStore,
    required String projectId,
  }) : _sessionService = sessionService,
       _selectionStore = selectionStore,
       _projectId = projectId,
       super(
         const NewSessionState.idle(
           availableAgents: [],
           availableProviders: [],
           availableCommands: [],
           selectedAgent: null,
           selectedAgentModel: null,
           stagedCommand: null,
           availableVariants: [],
         ),
       ) {
    _loadComposerData();
  }

  Future<void> _loadComposerData() async {
    try {
      final (
        ApiResponse<Agents> agentsResponse,
        ApiResponse<ProviderListResponse> providersResponse,
        ApiResponse<CommandListResponse> commandsResponse,
      ) = await wait3(
        _sessionService.listAgents(projectId: _projectId),
        _sessionService.listProviders(projectId: _projectId),
        _sessionService.listCommands(projectId: _projectId),
      );

      if (isClosed) return;

      _logComposerDataError(resource: "agents", response: agentsResponse);
      _logComposerDataError(resource: "providers", response: providersResponse);
      _logComposerDataError(resource: "commands", response: commandsResponse);

      final agents = switch (agentsResponse) {
        SuccessResponse(:final data) => data.agents.where((a) => !a.hidden && a.mode != AgentMode.subagent).toList(),
        ErrorResponse() => <AgentInfo>[],
      };

      final providers = switch (providersResponse) {
        SuccessResponse(:final data) => data.items,
        ErrorResponse() => <ProviderInfo>[],
      };
      final commands = switch (commandsResponse) {
        SuccessResponse(:final data) => data.items,
        ErrorResponse() => <CommandInfo>[],
      };

      final defaultAgent = agents.isNotEmpty ? agents.first.name : "build";
      final agentModel = agents.isNotEmpty ? agents.first.model : null;
      final AgentModel? defaultAgentModel;
      if (agentModel != null) {
        defaultAgentModel = agentModel;
      } else if (providers.isNotEmpty) {
        // Walk the provider list and use the first one that has at least
        // one available model. Previously we only looked at `providers.first`,
        // which silently produced `null` when the first provider happened
        // to be misconfigured or fully deprecated.
        AgentModel? pickedModel;
        for (final provider in providers) {
          final picked = _defaultModelSelector.pickFromProvider(
            models: provider.models,
          );
          if (picked != null) {
            pickedModel = AgentModel(
              providerID: provider.id,
              modelID: picked.id,
              variant: null,
            );
            break;
          }
        }
        defaultAgentModel = pickedModel;
      } else {
        defaultAgentModel = null;
      }

      // Restore a previously chosen (non-default) agent / model / variant so a
      // deliberate selection survives leaving and returning to the new-session
      // screen (where this cubit is recreated). Validate every part against the
      // freshly loaded data so a now-unavailable choice falls back to default.
      final (:selectedAgent, :selectedAgentModel) = _resolveInitialSelection(
        defaultAgent: defaultAgent,
        defaultAgentModel: defaultAgentModel,
        agents: agents,
        providers: providers,
      );

      _emitAgentModelUpdate(
        availableAgents: agents,
        availableProviders: providers,
        availableCommands: commands,
        selectedAgent: selectedAgent,
        selectedAgentModel: selectedAgentModel,
      );
    } catch (e, stackTrace) {
      loge("New session: failed to load composer data for project $_projectId", e, stackTrace);
      return;
    }
  }

  /// The composer degrades gracefully on partial failures (empty pickers),
  /// which previously made these errors invisible. Log them so missing
  /// agent/model pickers can be traced back to the failing request.
  void _logComposerDataError<T>({required String resource, required ApiResponse<T> response}) {
    if (response case ErrorResponse(:final error)) {
      loge("New session: failed to load $resource for project $_projectId", error);
    }
  }

  /// Applies agent/model field updates to the current state.
  /// No-op when the cubit is closed or in `created`.
  void _emitAgentModelUpdate({
    required List<AgentInfo>? availableAgents,
    required List<ProviderInfo>? availableProviders,
    required List<CommandInfo>? availableCommands,
    required String? selectedAgent,
    required AgentModel? selectedAgentModel,
  }) {
    if (isClosed) return;
    final current = state;
    final data = current.agentModelData;
    if (data == null) return;
    final derivedVariants = _deriveAvailableVariants(
      providers: availableProviders ?? data.providers,
      model: selectedAgentModel ?? data.agentModel,
    );
    switch (current) {
      case NewSessionIdle():
        emit(
          current.copyWith(
            availableAgents: availableAgents ?? current.availableAgents,
            availableProviders: availableProviders ?? current.availableProviders,
            availableCommands: availableCommands ?? current.availableCommands,
            selectedAgent: selectedAgent ?? current.selectedAgent,
            selectedAgentModel: selectedAgentModel ?? current.selectedAgentModel,
            availableVariants: derivedVariants,
          ),
        );
      case NewSessionSending():
        emit(
          current.copyWith(
            availableAgents: availableAgents ?? current.availableAgents,
            availableProviders: availableProviders ?? current.availableProviders,
            availableCommands: availableCommands ?? current.availableCommands,
            selectedAgent: selectedAgent ?? current.selectedAgent,
            selectedAgentModel: selectedAgentModel ?? current.selectedAgentModel,
            availableVariants: derivedVariants,
          ),
        );
      case NewSessionError():
        emit(
          current.copyWith(
            availableAgents: availableAgents ?? current.availableAgents,
            availableProviders: availableProviders ?? current.availableProviders,
            availableCommands: availableCommands ?? current.availableCommands,
            selectedAgent: selectedAgent ?? current.selectedAgent,
            selectedAgentModel: selectedAgentModel ?? current.selectedAgentModel,
            availableVariants: derivedVariants,
          ),
        );
      case NewSessionCreated():
        break;
    }
  }

  List<SessionVariant> _deriveAvailableVariants({
    required List<ProviderInfo> providers,
    required AgentModel? model,
  }) {
    final providerID = model?.providerID;
    final modelID = model?.modelID;
    final provider = providerID != null ? providers.firstWhereOrNull((p) => p.id == providerID) : null;
    final m = provider?.models[modelID];
    return m?.variants.where((v) => v != "none").map((v) => SessionVariant(id: v)).toList() ?? [];
  }

  /// Picks the agent / model / variant to start with: a previously persisted
  /// user selection (validated against the current [agents]/[providers]) when
  /// present and still available, otherwise the supplied defaults. Parts that
  /// are no longer available degrade independently to their default.
  ({String? selectedAgent, AgentModel? selectedAgentModel}) _resolveInitialSelection({
    required String? defaultAgent,
    required AgentModel? defaultAgentModel,
    required List<AgentInfo> agents,
    required List<ProviderInfo> providers,
  }) {
    final saved = _selectionStore.read(_projectId);
    if (saved == null) {
      return (selectedAgent: defaultAgent, selectedAgentModel: defaultAgentModel);
    }

    final savedAgent = saved.agent;
    final selectedAgent = (savedAgent != null && agents.any((a) => a.name == savedAgent))
        ? savedAgent
        : defaultAgent;

    final savedModel = saved.agentModel;
    AgentModel? selectedAgentModel = defaultAgentModel;
    if (savedModel != null && _modelIsAvailable(providers: providers, model: savedModel)) {
      // Drop a saved variant the model no longer offers.
      final availableVariants = _deriveAvailableVariants(providers: providers, model: savedModel);
      final variant = savedModel.variant;
      final validVariant = (variant != null && availableVariants.any((v) => v.id == variant)) ? variant : null;
      selectedAgentModel = savedModel.copyWith(variant: validVariant);
    }

    return (selectedAgent: selectedAgent, selectedAgentModel: selectedAgentModel);
  }

  bool _modelIsAvailable({required List<ProviderInfo> providers, required AgentModel model}) {
    final m = providers.firstWhereOrNull((p) => p.id == model.providerID)?.models[model.modelID];
    // Mirror the picker / DefaultModelSelector, which both filter on
    // `isAvailable`: a deprecated model lingers in the provider map with
    // `isAvailable: false`, so restoring it would show a selection absent from
    // the picker. Fall back to the default instead.
    return m != null && m.isAvailable;
  }

  /// Persists the current agent / model / variant selection so it survives a
  /// round-trip away from the new-session screen. Called after every explicit
  /// user change (never for the auto-computed default), so a stale entry can
  /// never shadow a future default.
  void _persistSelection() {
    final data = state.agentModelData;
    if (data == null) return;
    _selectionStore.write(_projectId, agent: data.agent, agentModel: data.agentModel);
  }

  void selectAgent(String agent) {
    final current = state;
    final agentInfo = switch (current) {
      NewSessionIdle() => current.availableAgents.firstWhereOrNull((a) => a.name == agent),
      NewSessionSending() => current.availableAgents.firstWhereOrNull((a) => a.name == agent),
      NewSessionError() => current.availableAgents.firstWhereOrNull((a) => a.name == agent),
      NewSessionCreated() => null,
    };
    final agentModel = agentInfo?.model;
    _emitAgentModelUpdate(
      selectedAgent: agent,
      selectedAgentModel: agentModel,
      availableAgents: null, // no change
      availableCommands: null, // no change
      availableProviders: null, // no change
    );
    _persistSelection();
  }

  void selectVariant(SessionVariant? variant) {
    final current = state;
    switch (current) {
      case NewSessionIdle():
        final agentModel = current.selectedAgentModel;
        if (agentModel == null) return;
        emit(current.copyWith(selectedAgentModel: agentModel.copyWith(variant: variant?.id)));
      case NewSessionSending():
        final agentModel = current.selectedAgentModel;
        if (agentModel == null) return;
        emit(current.copyWith(selectedAgentModel: agentModel.copyWith(variant: variant?.id)));
      case NewSessionError():
        final agentModel = current.selectedAgentModel;
        if (agentModel == null) return;
        emit(current.copyWith(selectedAgentModel: agentModel.copyWith(variant: variant?.id)));
      case NewSessionCreated():
        return;
    }
    _persistSelection();
  }

  void stageCommand(CommandInfo command) {
    final current = state;
    switch (current) {
      case NewSessionIdle():
        emit(current.copyWith(stagedCommand: command));
      case NewSessionSending():
        emit(current.copyWith(stagedCommand: command));
      case NewSessionError():
        emit(current.copyWith(stagedCommand: command));
      case NewSessionCreated():
        break;
    }
  }

  void clearStagedCommand() {
    final current = state;
    switch (current) {
      case NewSessionIdle():
        emit(current.copyWith(stagedCommand: null));
      case NewSessionSending():
        emit(current.copyWith(stagedCommand: null));
      case NewSessionError():
        emit(current.copyWith(stagedCommand: null));
      case NewSessionCreated():
        break;
    }
  }

  void selectModel({required String providerID, required String modelID}) {
    final current = state.agentModelData;
    if (current == null) return;

    final availableVariants = _deriveAvailableVariants(
      providers: current.providers,
      model: AgentModel(providerID: providerID, modelID: modelID, variant: null),
    );

    final agentModel = _resolveAgentModel(
      agents: current.agents,
      providerID: providerID,
      modelID: modelID,
    );

    final previousVariant = current.agentModel?.variant;
    final String? variant;
    if (previousVariant != null && availableVariants.any((v) => v.id == previousVariant)) {
      variant = previousVariant;
    } else {
      variant = agentModel?.variant ?? (availableVariants.isNotEmpty ? availableVariants.first.id : null);
    }

    _emitAgentModelUpdate(
      selectedAgentModel:
          agentModel?.copyWith(variant: variant) ??
          AgentModel(
            providerID: providerID,
            modelID: modelID,
            variant: variant,
          ),
      selectedAgent: null, // no change
      availableAgents: null, // no change
      availableCommands: null, // no change
      availableProviders: null, // no change
    );
    _persistSelection();
  }

  AgentModel? _resolveAgentModel({
    required List<AgentInfo> agents,
    required String providerID,
    required String modelID,
  }) {
    final agent = agents.firstWhereOrNull(
      (a) => a.model?.providerID == providerID && a.model?.modelID == modelID,
    );
    return agent?.model ??
        AgentModel(
          providerID: providerID,
          modelID: modelID,
          variant: null,
        );
  }

  Future<void> createSession({
    required String text,
    required bool dedicatedWorktree,
    required String? command,
  }) async {
    if (state is NewSessionSending) return;

    final normalizedCommand = command?.trim();
    final hasCommand = normalizedCommand != null && normalizedCommand.isNotEmpty;
    final trimmed = text.trim();
    if (trimmed.isEmpty && !hasCommand) return;

    final config = state.agentModelData;
    final variantId = config?.agentModel?.variant;

    emit(
      NewSessionState.sending(
        availableAgents: config?.agents ?? const [],
        availableProviders: config?.providers ?? const [],
        availableCommands: config?.commands ?? const [],
        selectedAgent: config?.agent,
        selectedAgentModel: config?.agentModel,
        stagedCommand: config?.stagedCommand,
        availableVariants: config?.availableVariants ?? const [],
      ),
    );

    final response = await _sessionService.createSessionWithMessage(
      projectId: _projectId,
      text: trimmed,
      agent: config?.agent,
      providerID: config?.agentModel?.providerID,
      modelID: config?.agentModel?.modelID,
      variant: variantId == null ? null : SessionVariant(id: variantId),
      command: normalizedCommand,
      dedicatedWorktree: dedicatedWorktree,
    );

    if (isClosed) return;

    switch (response) {
      case SuccessResponse(:final data):
        // The composer is done; drop the persisted selection so the next new
        // session for this project starts from the default (mirrors how a sent
        // prompt clears its text draft).
        _selectionStore.clear(_projectId);
        emit(NewSessionState.created(session: data));
      case ErrorResponse(:final error):
        loge("New session creation failed", error);
        // Read from current state (not pre-request snapshot) so that any
        // agent/provider data loaded while the request was in-flight is
        // preserved.
        final current = state.agentModelData;
        emit(
          NewSessionState.error(
            reason: error.remoteFailureReason,
            availableAgents: current?.agents ?? const [],
            availableProviders: current?.providers ?? const [],
            availableCommands: current?.commands ?? const [],
            selectedAgent: current?.agent,
            selectedAgentModel: current?.agentModel,
            stagedCommand: current?.stagedCommand,
            availableVariants: current?.availableVariants ?? const [],
          ),
        );
    }
  }
}
