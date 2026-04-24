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
    required String? selectedProviderID,
    required String? selectedModelID,
    required SessionVariant? selectedVariant,
    required CommandInfo? stagedCommand,
  }) = NewSessionIdle;

  const factory NewSessionState.sending({
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required List<CommandInfo> availableCommands,
    required List<SessionVariant> availableVariants,
    required String? selectedAgent,
    required String? selectedProviderID,
    required String? selectedModelID,
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
    required String? selectedProviderID,
    required String? selectedModelID,
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
  String? providerID,
  String? modelID,
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
      :final selectedProviderID,
      :final selectedModelID,
      :final selectedVariant,
      :final stagedCommand,
    ) =>
      (
        agents: availableAgents,
        providers: availableProviders,
        commands: availableCommands,
        availableVariants: availableVariants,
        agent: selectedAgent,
        providerID: selectedProviderID,
        modelID: selectedModelID,
        variant: selectedVariant,
        stagedCommand: stagedCommand,
      ),
    NewSessionSending(
      :final availableAgents,
      :final availableProviders,
      :final availableCommands,
      :final availableVariants,
      :final selectedAgent,
      :final selectedProviderID,
      :final selectedModelID,
      :final selectedVariant,
      :final stagedCommand,
    ) =>
      (
        agents: availableAgents,
        providers: availableProviders,
        commands: availableCommands,
        availableVariants: availableVariants,
        agent: selectedAgent,
        providerID: selectedProviderID,
        modelID: selectedModelID,
        variant: selectedVariant,
        stagedCommand: stagedCommand,
      ),
    NewSessionError(
      :final availableAgents,
      :final availableProviders,
      :final availableCommands,
      :final availableVariants,
      :final selectedAgent,
      :final selectedProviderID,
      :final selectedModelID,
      :final selectedVariant,
      :final stagedCommand,
    ) =>
      (
        agents: availableAgents,
        providers: availableProviders,
        commands: availableCommands,
        availableVariants: availableVariants,
        agent: selectedAgent,
        providerID: selectedProviderID,
        modelID: selectedModelID,
        variant: selectedVariant,
        stagedCommand: stagedCommand,
      ),
    NewSessionCreated() => null,
  };
}
