import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/session/session_service.dart";
import "new_session_state.dart";

class NewSessionCubit extends Cubit<NewSessionState> {
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
           selectedAgent: null,
           selectedProviderID: null,
           selectedModelID: null,
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

      _emitAgentModelUpdate(
        availableAgents: agents,
        availableProviders: providers,
        availableCommands: commands,
        selectedAgent: defaultAgent,
        selectedProviderID: defaultProviderID,
        selectedModelID: defaultModelID,
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
    String? selectedAgent,
    String? selectedProviderID,
    String? selectedModelID,
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
            selectedAgent: selectedAgent ?? current.selectedAgent,
            selectedProviderID: selectedProviderID ?? current.selectedProviderID,
            selectedModelID: selectedModelID ?? current.selectedModelID,
          ),
        );
      case NewSessionSending():
        emit(
          current.copyWith(
            availableAgents: availableAgents ?? current.availableAgents,
            availableProviders: availableProviders ?? current.availableProviders,
            availableCommands: availableCommands ?? current.availableCommands,
            selectedAgent: selectedAgent ?? current.selectedAgent,
            selectedProviderID: selectedProviderID ?? current.selectedProviderID,
            selectedModelID: selectedModelID ?? current.selectedModelID,
          ),
        );
      case NewSessionError():
        emit(
          current.copyWith(
            availableAgents: availableAgents ?? current.availableAgents,
            availableProviders: availableProviders ?? current.availableProviders,
            availableCommands: availableCommands ?? current.availableCommands,
            selectedAgent: selectedAgent ?? current.selectedAgent,
            selectedProviderID: selectedProviderID ?? current.selectedProviderID,
            selectedModelID: selectedModelID ?? current.selectedModelID,
          ),
        );
      case NewSessionCreated():
        break;
    }
  }

  void selectAgent(String agent) {
    _emitAgentModelUpdate(selectedAgent: agent);
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
    String? command,
  }) async {
    if (state is NewSessionSending) return;

    final hasCommand = command != null && command.isNotEmpty;
    final trimmed = text.trim();
    if (trimmed.isEmpty && !hasCommand) return;

    final config = state.agentModelData;

    // When executing a command, agent/model selection is irrelevant.
    final String? agent = hasCommand ? null : config?.agent;
    final PromptModel? model;
    if (hasCommand) {
      model = null;
    } else {
      final selectedProviderID = config?.providerID;
      final selectedModelID = config?.modelID;
      model =
          selectedProviderID != null &&
              selectedProviderID.isNotEmpty &&
              selectedModelID != null &&
              selectedModelID.isNotEmpty
          ? PromptModel(providerID: selectedProviderID, modelID: selectedModelID)
          : null;
    }

    emit(
      NewSessionState.sending(
        availableAgents: config?.agents ?? const [],
        availableProviders: config?.providers ?? const [],
        availableCommands: config?.commands ?? const [],
        selectedAgent: config?.agent,
        selectedProviderID: config?.providerID,
        selectedModelID: config?.modelID,
        stagedCommand: config?.stagedCommand,
      ),
    );

    final response = await _sessionService.createSessionWithMessage(
      projectId: _projectId,
      text: trimmed,
      agent: agent,
      model: model,
      command: command,
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
            selectedAgent: current?.agent,
            selectedProviderID: current?.providerID,
            selectedModelID: current?.modelID,
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
}
