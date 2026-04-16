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
           selectedAgent: null,
           selectedProviderID: null,
           selectedModelID: null,
         ),
       ) {
    _loadAgentModelData();
  }

  Future<void> _loadAgentModelData() async {
    try {
      final (agentsResponse, providersResponse) = await (
        _sessionService.listAgents(),
        _sessionService.listProviders(),
      ).wait;

      if (isClosed) return;

      final agents = switch (agentsResponse) {
        SuccessResponse(:final data) => data.agents.where((a) => !a.hidden && a.mode != AgentMode.subagent).toList(),
        ErrorResponse() => <AgentInfo>[],
      };

      final providers = switch (providersResponse) {
        SuccessResponse(:final data) => data.items,
        ErrorResponse() => <ProviderInfo>[],
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

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit API consumed by UI layer
  void selectModel(String providerID, String modelID) {
    _emitAgentModelUpdate(selectedProviderID: providerID, selectedModelID: modelID);
  }

  Future<void> createSessionWithMessage({
    required String text,
    required bool dedicatedWorktree,
  }) async {
    if (state is NewSessionSending) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final config = state.agentModelData;
    final selectedProviderID = config?.providerID;
    final selectedModelID = config?.modelID;
    final model =
        selectedProviderID != null &&
            selectedProviderID.isNotEmpty &&
            selectedModelID != null &&
            selectedModelID.isNotEmpty
        ? PromptModel(providerID: selectedProviderID, modelID: selectedModelID)
        : null;

    emit(
      NewSessionState.sending(
        availableAgents: config?.agents ?? const [],
        availableProviders: config?.providers ?? const [],
        selectedAgent: config?.agent,
        selectedProviderID: selectedProviderID,
        selectedModelID: selectedModelID,
      ),
    );

    final response = await _sessionService.createSessionWithMessage(
      projectId: _projectId,
      text: trimmed,
      agent: config?.agent,
      model: model,
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
            selectedAgent: current?.agent,
            selectedProviderID: current?.providerID,
            selectedModelID: current?.modelID,
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
