import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "../../services/models/new_session_backend_scope.dart";
import "../../services/models/new_session_options_source.dart";
import "../../services/new_session_options_service.dart";
import "new_session_submission_snapshot.dart";

part "new_session_state.freezed.dart";

@Freezed()
sealed class NewSessionOptionsLoadState with _$NewSessionOptionsLoadState {
  const factory loading({required NewSessionOptionsSource? source}) = NewSessionOptionsLoadingState;

  const factory refreshing({
    required NewSessionOptionsData options,
    required NewSessionOptionsSource source,
  }) = NewSessionOptionsRefreshingState;

  const factory available({
    required NewSessionOptionsData options,
    required NewSessionOptionsSource source,
  }) = NewSessionOptionsAvailableState;

  const factory unsupported() = NewSessionOptionsUnsupportedState;

  const factory unavailable() = NewSessionOptionsUnavailableState;

  const factory loadFailureUnavailable() = NewSessionOptionsLoadFailureUnavailableState;

  const factory authenticationRequiredUnavailable({
    required String actionHint,
  }) = NewSessionOptionsAuthenticationRequiredUnavailableState;

  const factory authenticationRequiredRetained({
    required String actionHint,
    required NewSessionOptionsData options,
    required NewSessionOptionsSource source,
  }) = NewSessionOptionsAuthenticationRequiredRetainedState;

  const factory failure({
    required RemoteFailureReason reason,
    required NewSessionOptionsSource source,
  }) = NewSessionOptionsFailureState;

  const factory failureRetained({
    required NewSessionOptionsData options,
    required NewSessionOptionsSource source,
  }) = NewSessionOptionsFailureRetainedState;

  const factory refreshFailureUnavailable() = NewSessionOptionsRefreshFailureUnavailableState;
}

extension NewSessionOptionsLoadStateData on NewSessionOptionsLoadState {
  NewSessionOptionsData? get data => switch (this) {
    NewSessionOptionsRefreshingState(:final options) ||
    NewSessionOptionsAvailableState(:final options) ||
    NewSessionOptionsAuthenticationRequiredRetainedState(:final options) ||
    NewSessionOptionsFailureRetainedState(:final options) => options,
    NewSessionOptionsLoadingState() ||
    NewSessionOptionsUnsupportedState() ||
    NewSessionOptionsUnavailableState() ||
    NewSessionOptionsLoadFailureUnavailableState() ||
    NewSessionOptionsAuthenticationRequiredUnavailableState() ||
    NewSessionOptionsFailureState() ||
    NewSessionOptionsRefreshFailureUnavailableState() => null,
  };

  bool get isLoading => this is NewSessionOptionsLoadingState || this is NewSessionOptionsRefreshingState;

  NewSessionOptionsSource? get source => switch (this) {
    NewSessionOptionsLoadingState(:final source) => source,
    NewSessionOptionsRefreshingState(:final source) ||
    NewSessionOptionsAvailableState(:final source) ||
    NewSessionOptionsAuthenticationRequiredRetainedState(:final source) ||
    NewSessionOptionsFailureState(:final source) ||
    NewSessionOptionsFailureRetainedState(:final source) => source,
    NewSessionOptionsUnsupportedState() => NewSessionOptionsSource.legacy,
    NewSessionOptionsUnavailableState() ||
    NewSessionOptionsLoadFailureUnavailableState() ||
    NewSessionOptionsAuthenticationRequiredUnavailableState() ||
    NewSessionOptionsRefreshFailureUnavailableState() => NewSessionOptionsSource.aggregate,
  };

  bool get authenticationRequired =>
      this is NewSessionOptionsAuthenticationRequiredUnavailableState ||
      this is NewSessionOptionsAuthenticationRequiredRetainedState;
}

enum NewSessionProjectWorktreeCapability() {
  loading,
  supported,
  unsupported,
  unavailable,
}

/// The composer's configuration: what the bridge can run and what the project
/// supports, independent of where the creation flow currently stands.
@Freezed()
sealed class NewSessionComposeConfig with _$NewSessionComposeConfig {
  const factory({
    required List<PluginMetadata> availablePlugins,
    required PluginMetadata? selectedPlugin,
    required NewSessionOptionsLoadState options,
    required NewSessionBackendScope backendScope,
    required bool isPluginDiscoveryInFlight,
    required NewSessionProjectWorktreeCapability projectWorktreeCapability,
  }) = _NewSessionComposeConfig;
}

/// Where the creation flow stands while the composer is on screen. Each
/// variant carries only the data valid in that phase, so a retained submission
/// or a creation reason cannot be dropped by an unrelated configuration
/// update.
@Freezed()
sealed class NewSessionPhase with _$NewSessionPhase {
  const factory idle() = NewSessionPhaseIdle;

  const factory sending({required NewSessionSubmissionSnapshot submission}) = NewSessionPhaseSending;

  const factory restoringSubmission({
    required NewSessionSubmissionSnapshot submission,
    required RemoteFailureReason reason,
  }) = NewSessionPhaseRestoringSubmission;

  const factory creationError({required RemoteFailureReason reason}) = NewSessionPhaseCreationError;

  const factory discoveryError({required RemoteFailureReason reason}) = NewSessionPhaseDiscoveryError;
}

@Freezed()
sealed class NewSessionState with _$NewSessionState {
  const factory composing({
    required NewSessionComposeConfig config,
    required NewSessionPhase phase,
  }) = NewSessionComposing;

  const factory created({required Session session}) = NewSessionCreated;
}

typedef AgentModelData = ({
  List<PluginMetadata> plugins,
  PluginMetadata? plugin,
  NewSessionOptionsLoadState optionsState,
  NewSessionBackendScope backendScope,
  bool isLoading,
  bool isPluginDiscoveryInFlight,
  List<AgentInfo> agents,
  List<ProviderInfo> providers,
  List<CommandInfo> commands,
  String? agent,
  AgentModel? agentModel,
  CommandInfo? stagedCommand,
  List<SessionVariant> availableVariants,
  NewSessionProjectWorktreeCapability projectWorktreeCapability,
});

extension NewSessionComposeConfigAgentModel on NewSessionComposeConfig {
  AgentModelData get agentModelData {
    final data = options.data;
    return (
      plugins: availablePlugins,
      plugin: selectedPlugin,
      optionsState: options,
      backendScope: backendScope,
      isLoading: options.isLoading || projectWorktreeCapability == NewSessionProjectWorktreeCapability.loading,
      isPluginDiscoveryInFlight: isPluginDiscoveryInFlight,
      agents: data?.agents ?? const [],
      providers: data?.providers ?? const [],
      commands: data?.commands ?? const [],
      agent: data?.selectedAgent,
      agentModel: data?.selectedAgentModel,
      stagedCommand: data?.stagedCommand,
      availableVariants: data?.availableVariants ?? const [],
      projectWorktreeCapability: projectWorktreeCapability,
    );
  }
}

extension NewSessionStateAgentModel on NewSessionState {
  NewSessionComposeConfig? get config => switch (this) {
    NewSessionComposing(:final config) => config,
    NewSessionCreated() => null,
  };

  NewSessionPhase? get phase => switch (this) {
    NewSessionComposing(:final phase) => phase,
    NewSessionCreated() => null,
  };

  AgentModelData? get agentModelData => config?.agentModelData;

  bool get isComposerDataLoading => agentModelData?.isLoading ?? false;
  List<AgentInfo> get availableAgents => agentModelData?.agents ?? const [];
  List<ProviderInfo> get availableProviders => agentModelData?.providers ?? const [];
  List<CommandInfo> get availableCommands => agentModelData?.commands ?? const [];
  String? get selectedAgent => agentModelData?.agent;
  AgentModel? get selectedAgentModel => agentModelData?.agentModel;
  CommandInfo? get stagedCommand => agentModelData?.stagedCommand;
  List<SessionVariant> get availableVariants => agentModelData?.availableVariants ?? const [];
}
