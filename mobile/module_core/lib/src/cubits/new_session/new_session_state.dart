import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "new_session_state.freezed.dart";

@Freezed()
sealed class NewSessionState with _$NewSessionState {
  const factory NewSessionState.idle({
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required List<CommandInfo> availableCommands,
    required List<SessionVariant> availableVariants,
    required String? selectedAgent,
    required AgentModel? selectedAgentModel,
    required SessionVariant? selectedVariant,
    required CommandInfo? stagedCommand,
  }) = NewSessionIdle;

  const factory NewSessionState.sending({
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required List<CommandInfo> availableCommands,
    required List<SessionVariant> availableVariants,
    required String? selectedAgent,
    required AgentModel? selectedAgentModel,
    required SessionVariant? selectedVariant,
    required CommandInfo? stagedCommand,
  }) = NewSessionSending;

  const factory NewSessionState.error({
    required String message,
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required List<CommandInfo> availableCommands,
    required List<SessionVariant> availableVariants,
    required String? selectedAgent,
    required AgentModel? selectedAgentModel,
    required SessionVariant? selectedVariant,
    required CommandInfo? stagedCommand,
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
  List<SessionVariant> availableVariants,
  String? agent,
  AgentModel? agentModel,
  SessionVariant? variant,
  CommandInfo? stagedCommand,
});

extension NewSessionStateAgentModel on NewSessionState {
  AgentModelData? get agentModelData => switch (this) {
    NewSessionIdle(
      :final availableAgents,
      :final availableProviders,
      :final availableCommands,
      :final availableVariants,
      :final selectedAgent,
      :final selectedAgentModel,
      :final selectedVariant,
      :final stagedCommand,
    ) =>
      (
        agents: availableAgents,
        providers: availableProviders,
        commands: availableCommands,
        availableVariants: availableVariants,
        agent: selectedAgent,
        agentModel: selectedAgentModel,
        variant: selectedVariant,
        stagedCommand: stagedCommand,
      ),
    NewSessionSending(
      :final availableAgents,
      :final availableProviders,
      :final availableCommands,
      :final availableVariants,
      :final selectedAgent,
      :final selectedAgentModel,
      :final selectedVariant,
      :final stagedCommand,
    ) =>
      (
        agents: availableAgents,
        providers: availableProviders,
        commands: availableCommands,
        availableVariants: availableVariants,
        agent: selectedAgent,
        agentModel: selectedAgentModel,
        variant: selectedVariant,
        stagedCommand: stagedCommand,
      ),
    NewSessionError(
      :final availableAgents,
      :final availableProviders,
      :final availableCommands,
      :final availableVariants,
      :final selectedAgent,
      :final selectedAgentModel,
      :final selectedVariant,
      :final stagedCommand,
    ) =>
      (
        agents: availableAgents,
        providers: availableProviders,
        commands: availableCommands,
        availableVariants: availableVariants,
        agent: selectedAgent,
        agentModel: selectedAgentModel,
        variant: selectedVariant,
        stagedCommand: stagedCommand,
      ),
    NewSessionCreated() => null,
  };
}
