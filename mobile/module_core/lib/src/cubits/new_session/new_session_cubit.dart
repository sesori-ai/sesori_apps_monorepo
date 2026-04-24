import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/session/session_service.dart";
import "new_session_state.dart";

class NewSessionCubit extends Cubit<NewSessionState> {
  static const _noChange = Object();

  final SessionService _sessionService;
  final String _projectId;

  NewSessionCubit({
    required SessionService sessionService,
    required String projectId,
  }) : _sessionService = sessionService,
       _projectId = projectId,
       super(
          const NewSessionState.idle(
            availableAgents: [],
            availableProviders: [],
            availableCommands: [],
            availableVariants: [],
            selectedAgent: null,
            selectedProviderID: null,
            selectedModelID: null,
            selectedVariant: null,
            stagedCommand: null,
          ),
        ) {
    _loadComposerData();
  }

  Future<void> _loadComposerData() async {
    try {
      final (agentsResponse, providersResponse, commandsResponse) = await wait3(
        _sessionService.listAgents(),
        _sessionService.listProviders(),
        _sessionService.listCommands(projectId: _projectId),
      );

      if (isClosed) return;

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
      final String defaultProviderID;
      final String defaultModelID;
      if (agentModel != null) {
        defaultProviderID = agentModel.providerID;
        defaultModelID = agentModel.modelID;
      } else if (providers.isNotEmpty) {
        defaultProviderID = providers.first.id;
        final firstProviderDefaultModelId = providers.first.defaultModelID;
        defaultModelID =
            firstProviderDefaultModelId != null && providers.first.models.containsKey(firstProviderDefaultModelId)
            ? firstProviderDefaultModelId
            : providers.first.models.values.first.id;
      } else {
        defaultProviderID = "";
        defaultModelID = "";
      }

      final availableVariants = _computeVariants(agents: agents, selectedAgentName: defaultAgent);

      _emitAgentModelUpdate(
        availableAgents: agents,
        availableProviders: providers,
        availableCommands: commands,
        availableVariants: availableVariants,
        selectedAgent: defaultAgent,
        selectedProviderID: defaultProviderID,
        selectedModelID: defaultModelID,
        selectedVariant: null,
      );
    } catch (_) {
      return;
    }
  }

  /// Applies agent/model field updates to the current state, regardless of
  /// which variant is active. No-op when the cubit is closed or in `created`.
  // ignore: no_slop_linter/prefer_required_named_parameters, optional state patch parameters
  void _emitAgentModelUpdate({
    List<AgentInfo>? availableAgents,
    List<ProviderInfo>? availableProviders,
    List<CommandInfo>? availableCommands,
    List<String>? availableVariants,
    String? selectedAgent,
    String? selectedProviderID,
    String? selectedModelID,
    Object? selectedVariant = _noChange,
  }) {
    if (isClosed) return;
    final current = state;
    switch (current) {
      case NewSessionIdle():
        emit(
          current.copyWith(
            availableAgents: availableAgents ?? current.availableAgents,
            availableProviders: availableProviders ?? current.availableProviders,
            availableCommands: availableCommands ?? current.availableCommands,
            availableVariants: availableVariants ?? current.availableVariants,
            selectedAgent: selectedAgent ?? current.selectedAgent,
            selectedProviderID: selectedProviderID ?? current.selectedProviderID,
            selectedModelID: selectedModelID ?? current.selectedModelID,
            selectedVariant: selectedVariant == _noChange ? current.selectedVariant : selectedVariant as String?,
          ),
        );
      case NewSessionSending():
        emit(
          current.copyWith(
            availableAgents: availableAgents ?? current.availableAgents,
            availableProviders: availableProviders ?? current.availableProviders,
            availableCommands: availableCommands ?? current.availableCommands,
            availableVariants: availableVariants ?? current.availableVariants,
            selectedAgent: selectedAgent ?? current.selectedAgent,
            selectedProviderID: selectedProviderID ?? current.selectedProviderID,
            selectedModelID: selectedModelID ?? current.selectedModelID,
            selectedVariant: selectedVariant == _noChange ? current.selectedVariant : selectedVariant as String?,
          ),
        );
      case NewSessionError():
        emit(
          current.copyWith(
            availableAgents: availableAgents ?? current.availableAgents,
            availableProviders: availableProviders ?? current.availableProviders,
            availableCommands: availableCommands ?? current.availableCommands,
            availableVariants: availableVariants ?? current.availableVariants,
            selectedAgent: selectedAgent ?? current.selectedAgent,
            selectedProviderID: selectedProviderID ?? current.selectedProviderID,
            selectedModelID: selectedModelID ?? current.selectedModelID,
            selectedVariant: selectedVariant == _noChange ? current.selectedVariant : selectedVariant as String?,
          ),
        );
      case NewSessionCreated():
        break;
    }
  }

  void selectAgent(String agent) {
    final current = state.agentModelData;
    if (current == null) return;

    _emitAgentModelUpdate(
      selectedAgent: agent,
      availableVariants: _computeVariants(agents: current.agents, selectedAgentName: agent),
      selectedVariant: null,
    );
  }

  void selectVariant(String? variant) {
    _emitAgentModelUpdate(selectedVariant: variant);
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

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit API consumed by UI layer
  void selectModel(String providerID, String modelID) {
    _emitAgentModelUpdate(selectedProviderID: providerID, selectedModelID: modelID);
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

    emit(
      NewSessionState.sending(
        availableAgents: config?.agents ?? const [],
        availableProviders: config?.providers ?? const [],
        availableCommands: config?.commands ?? const [],
        availableVariants: config?.availableVariants ?? const [],
        selectedAgent: config?.agent,
        selectedProviderID: config?.providerID,
        selectedModelID: config?.modelID,
        selectedVariant: config?.variant,
        stagedCommand: config?.stagedCommand,
      ),
    );

    final response = await _sessionService.createSessionWithMessage(
      projectId: _projectId,
      text: trimmed,
      agent: config?.agent,
      providerID: config?.providerID,
      modelID: config?.modelID,
      variant: config?.variant,
      command: normalizedCommand,
      dedicatedWorktree: dedicatedWorktree,
    );

    if (isClosed) return;

    switch (response) {
      case SuccessResponse(:final data):
        emit(NewSessionState.created(session: data));
      case ErrorResponse(:final error):
        // Read from current state (not pre-request snapshot) so that any
        // agent/provider data loaded while the request was in-flight is
        // preserved.
        final current = state.agentModelData;
        emit(
          NewSessionState.error(
            message: _describeError(error: error),
            availableAgents: current?.agents ?? const [],
            availableProviders: current?.providers ?? const [],
            availableCommands: current?.commands ?? const [],
            availableVariants: current?.availableVariants ?? const [],
            selectedAgent: current?.agent,
            selectedProviderID: current?.providerID,
            selectedModelID: current?.modelID,
            selectedVariant: current?.variant,
            stagedCommand: current?.stagedCommand,
          ),
        );
    }
  }

  String _describeError({required ApiError error}) {
    return switch (error) {
      NotAuthenticatedError() => "Authentication required.",
      NonSuccessCodeError(:final rawErrorString) => rawErrorString ?? "Failed to create session.",
      DartHttpClientError() => "Unable to reach server.",
      JsonParsingError() => "Unexpected server response.",
      GenericError() => "Failed to create session.",
      EmptyResponseError() => "Empty response from server.",
    };
  }

  List<String> _computeVariants({
    required List<AgentInfo> agents,
    required String? selectedAgentName,
  }) {
    if (selectedAgentName == null) {
      return const [];
    }

    final variants = <String>[];
    for (final agent in agents) {
      final variant = agent.variant;
      if (agent.name != selectedAgentName || variant == null || variant == "none") {
        continue;
      }
      if (!variants.contains(variant)) {
        variants.add(variant);
      }
    }
    return variants;
  }
}
