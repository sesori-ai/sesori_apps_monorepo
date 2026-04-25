import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
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
            selectedAgentModel: null,
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
      final AgentModel? defaultAgentModel;
      if (agentModel != null) {
        defaultAgentModel = agentModel;
      } else if (providers.isNotEmpty) {
        final firstProvider = providers.first;
        final defaultModelID = firstProvider.defaultModelID;
        final modelID = defaultModelID != null && firstProvider.models.containsKey(defaultModelID)
            ? defaultModelID
            : firstProvider.models.values.first.id;
        defaultAgentModel = AgentModel(
          providerID: firstProvider.id,
          modelID: modelID,
          variant: null,
        );
      } else {
        defaultAgentModel = null;
      }

      _emitAgentModelUpdate(
        availableAgents: agents,
        availableProviders: providers,
        availableCommands: commands,
        selectedAgent: defaultAgent,
        selectedAgentModel: defaultAgentModel,
      );
    } catch (_) {
      return;
    }
  }

  /// Applies agent/model field updates to the current state.
  /// No-op when the cubit is closed or in `created`.
  void _emitAgentModelUpdate({
    List<AgentInfo>? availableAgents,
    List<ProviderInfo>? availableProviders,
    List<CommandInfo>? availableCommands,
    String? selectedAgent,
    AgentModel? selectedAgentModel,
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
            selectedAgentModel: selectedAgentModel ?? current.selectedAgentModel,
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
          ),
        );
      case NewSessionCreated():
        break;
    }
  }

  void selectAgent(String agent) {
    _emitAgentModelUpdate(selectedAgent: agent);
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

  void selectModel(String providerID, String modelID) {
    final current = state.agentModelData;
    if (current == null) return;

    final agentModel = _resolveAgentModel(
      agents: current.agents,
      providerID: providerID,
      modelID: modelID,
    );

    _emitAgentModelUpdate(
      selectedAgentModel: agentModel,
    );
  }

  AgentModel? _resolveAgentModel({
    required List<AgentInfo> agents,
    required String providerID,
    required String modelID,
  }) {
    final agent = agents.firstWhereOrNull(
      (a) => a.model?.providerID == providerID && a.model?.modelID == modelID,
    );
    return agent?.model ?? AgentModel(
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
            selectedAgentModel: current?.agentModel,
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
