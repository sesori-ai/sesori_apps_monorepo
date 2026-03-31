import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "new_session_state.freezed.dart";

@Freezed()
sealed class NewSessionState with _$NewSessionState {
  // ignore: no_slop_linter/prefer_required_named_parameters, optional state selection fields
  const factory NewSessionState.idle({
    @Default([]) List<AgentInfo> availableAgents,
    @Default([]) List<ProviderInfo> availableProviders,
    // ignore: no_slop_linter/prefer_required_named_parameters, optional state field
    String? selectedAgent,
    // ignore: no_slop_linter/prefer_required_named_parameters, optional state field
    String? selectedProviderID,
    // ignore: no_slop_linter/prefer_required_named_parameters, optional state field
    String? selectedModelID,
  }) = NewSessionIdle;

  // ignore: no_slop_linter/prefer_required_named_parameters, optional state selection fields
  const factory NewSessionState.sending({
    @Default([]) List<AgentInfo> availableAgents,
    @Default([]) List<ProviderInfo> availableProviders,
    // ignore: no_slop_linter/prefer_required_named_parameters, optional state field
    String? selectedAgent,
    // ignore: no_slop_linter/prefer_required_named_parameters, optional state field
    String? selectedProviderID,
    // ignore: no_slop_linter/prefer_required_named_parameters, optional state field
    String? selectedModelID,
  }) = NewSessionSending;

  // ignore: no_slop_linter/prefer_required_named_parameters, optional state selection fields
  const factory NewSessionState.error({
    required String message,
    @Default([]) List<AgentInfo> availableAgents,
    @Default([]) List<ProviderInfo> availableProviders,
    // ignore: no_slop_linter/prefer_required_named_parameters, optional state field
    String? selectedAgent,
    // ignore: no_slop_linter/prefer_required_named_parameters, optional state field
    String? selectedProviderID,
    // ignore: no_slop_linter/prefer_required_named_parameters, optional state field
    String? selectedModelID,
  }) = NewSessionError;

  const factory NewSessionState.created({required Session session}) = NewSessionCreated;
}

/// Convenience accessor for agent/model selection data shared across
/// the [NewSessionIdle], [NewSessionSending], and [NewSessionError] variants.
/// Returns `null` for [NewSessionCreated] (where the data is irrelevant).
typedef AgentModelData = ({
  List<AgentInfo> agents,
  List<ProviderInfo> providers,
  String? agent,
  String? providerID,
  String? modelID,
});

extension NewSessionStateAgentModel on NewSessionState {
  AgentModelData? get agentModelData => switch (this) {
    NewSessionIdle(
      :final availableAgents,
      :final availableProviders,
      :final selectedAgent,
      :final selectedProviderID,
      :final selectedModelID,
    ) =>
      (
        agents: availableAgents,
        providers: availableProviders,
        agent: selectedAgent,
        providerID: selectedProviderID,
        modelID: selectedModelID,
      ),
    NewSessionSending(
      :final availableAgents,
      :final availableProviders,
      :final selectedAgent,
      :final selectedProviderID,
      :final selectedModelID,
    ) =>
      (
        agents: availableAgents,
        providers: availableProviders,
        agent: selectedAgent,
        providerID: selectedProviderID,
        modelID: selectedModelID,
      ),
    NewSessionError(
      :final availableAgents,
      :final availableProviders,
      :final selectedAgent,
      :final selectedProviderID,
      :final selectedModelID,
    ) =>
      (
        agents: availableAgents,
        providers: availableProviders,
        agent: selectedAgent,
        providerID: selectedProviderID,
        modelID: selectedModelID,
      ),
    NewSessionCreated() => null,
  };
}
