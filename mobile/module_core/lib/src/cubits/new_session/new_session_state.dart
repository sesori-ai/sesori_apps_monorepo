import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "new_session_state.freezed.dart";

@Freezed()
sealed class NewSessionState with _$NewSessionState {
  const factory NewSessionState.idle({
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required List<CommandInfo> availableCommands,
    required String? selectedAgent,
    required AgentModel? selectedAgentModel,
    required CommandInfo? stagedCommand,
    @Default([]) List<SessionVariant> availableVariants,
    SessionVariant? selectedVariant,
  }) = NewSessionIdle;

  const factory NewSessionState.sending({
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required List<CommandInfo> availableCommands,
    required String? selectedAgent,
    required AgentModel? selectedAgentModel,
    required CommandInfo? stagedCommand,
    @Default([]) List<SessionVariant> availableVariants,
    SessionVariant? selectedVariant,
  }) = NewSessionSending;

  const factory NewSessionState.error({
    required String message,
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required List<CommandInfo> availableCommands,
    required String? selectedAgent,
    required AgentModel? selectedAgentModel,
    required CommandInfo? stagedCommand,
    @Default([]) List<SessionVariant> availableVariants,
    SessionVariant? selectedVariant,
  }) = NewSessionError;

  const factory NewSessionState.created({required Session session}) = NewSessionCreated;
}

/// Convenience accessor for agent/model selection data shared across
/// the [NewSessionIdle], [NewSessionSending], and [NewSessionError] variants.
/// Returns `null` for [NewSessionCreated] (where the data is irrelevant).
typedef AgentModelData = ({
  List<AgentInfo> agents,
  List<ProviderInfo> providers,
  List<CommandInfo> commands,
  String? agent,
  AgentModel? agentModel,
  CommandInfo? stagedCommand,
  List<SessionVariant> availableVariants,
  SessionVariant? selectedVariant,
});

extension NewSessionStateAgentModel on NewSessionState {
  AgentModelData? get agentModelData => switch (this) {
    NewSessionIdle(
      :final availableAgents,
      :final availableProviders,
      :final availableCommands,
      :final selectedAgent,
      :final selectedAgentModel,
      :final stagedCommand,
      :final availableVariants,
      :final selectedVariant,
    ) =>
      (
        agents: availableAgents,
        providers: availableProviders,
        commands: availableCommands,
        agent: selectedAgent,
        agentModel: selectedAgentModel,
        stagedCommand: stagedCommand,
        availableVariants: availableVariants,
        selectedVariant: selectedVariant,
      ),
    NewSessionSending(
      :final availableAgents,
      :final availableProviders,
      :final availableCommands,
      :final selectedAgent,
      :final selectedAgentModel,
      :final stagedCommand,
      :final availableVariants,
      :final selectedVariant,
    ) =>
      (
        agents: availableAgents,
        providers: availableProviders,
        commands: availableCommands,
        agent: selectedAgent,
        agentModel: selectedAgentModel,
        stagedCommand: stagedCommand,
        availableVariants: availableVariants,
        selectedVariant: selectedVariant,
      ),
    NewSessionError(
      :final availableAgents,
      :final availableProviders,
      :final availableCommands,
      :final selectedAgent,
      :final selectedAgentModel,
      :final stagedCommand,
      :final availableVariants,
      :final selectedVariant,
    ) =>
      (
        agents: availableAgents,
        providers: availableProviders,
        commands: availableCommands,
        agent: selectedAgent,
        agentModel: selectedAgentModel,
        stagedCommand: stagedCommand,
        availableVariants: availableVariants,
        selectedVariant: selectedVariant,
      ),
    NewSessionCreated() => null,
  };
}
