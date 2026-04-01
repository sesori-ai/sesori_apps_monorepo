import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "new_session_state.freezed.dart";

@Freezed()
sealed class NewSessionState with _$NewSessionState {
  const factory NewSessionState.idle({
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required String? selectedAgent,
    required String? selectedProviderID,
    required String? selectedModelID,
  }) = NewSessionIdle;

  const factory NewSessionState.sending({
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required String? selectedAgent,
    required String? selectedProviderID,
    required String? selectedModelID,
  }) = NewSessionSending;

  const factory NewSessionState.error({
    required String message,
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required String? selectedAgent,
    required String? selectedProviderID,
    required String? selectedModelID,
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
