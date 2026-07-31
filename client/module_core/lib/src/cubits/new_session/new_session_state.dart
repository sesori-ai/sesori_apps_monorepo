import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "../../services/models/new_session_options_source.dart";
import "../../services/new_session_options_service.dart";

part "new_session_state.freezed.dart";

@Freezed()
sealed class NewSessionOptionsLoadState with _$NewSessionOptionsLoadState {
  const factory NewSessionOptionsLoadState.loading({required NewSessionOptionsSource? source}) =
      NewSessionOptionsLoadingState;

  const factory NewSessionOptionsLoadState.refreshing({
    required NewSessionOptionsData options,
    required NewSessionOptionsSource source,
  }) = NewSessionOptionsRefreshingState;

  const factory NewSessionOptionsLoadState.available({
    required NewSessionOptionsData options,
    required NewSessionOptionsSource source,
  }) = NewSessionOptionsAvailableState;

  const factory NewSessionOptionsLoadState.unsupported() = NewSessionOptionsUnsupportedState;

  const factory NewSessionOptionsLoadState.unavailable() = NewSessionOptionsUnavailableState;

  const factory NewSessionOptionsLoadState.failure({
    required RemoteFailureReason reason,
    required NewSessionOptionsSource source,
  }) = NewSessionOptionsFailureState;

  const factory NewSessionOptionsLoadState.refreshFailureRetained({
    required NewSessionOptionsData options,
    required NewSessionOptionsSource source,
  }) = NewSessionOptionsRefreshFailureRetainedState;

  const factory NewSessionOptionsLoadState.refreshFailureUnavailable() =
      NewSessionOptionsRefreshFailureUnavailableState;
}

extension NewSessionOptionsLoadStateData on NewSessionOptionsLoadState {
  NewSessionOptionsData? get data => switch (this) {
    NewSessionOptionsRefreshingState(:final options) ||
    NewSessionOptionsAvailableState(:final options) ||
    NewSessionOptionsRefreshFailureRetainedState(:final options) => options,
    NewSessionOptionsLoadingState() ||
    NewSessionOptionsUnsupportedState() ||
    NewSessionOptionsUnavailableState() ||
    NewSessionOptionsFailureState() ||
    NewSessionOptionsRefreshFailureUnavailableState() => null,
  };

  bool get isLoading => this is NewSessionOptionsLoadingState || this is NewSessionOptionsRefreshingState;

  NewSessionOptionsSource? get source => switch (this) {
    NewSessionOptionsLoadingState(:final source) => source,
    NewSessionOptionsRefreshingState(:final source) ||
    NewSessionOptionsAvailableState(:final source) ||
    NewSessionOptionsFailureState(:final source) ||
    NewSessionOptionsRefreshFailureRetainedState(:final source) => source,
    NewSessionOptionsUnsupportedState() => NewSessionOptionsSource.legacy,
    NewSessionOptionsUnavailableState() ||
    NewSessionOptionsRefreshFailureUnavailableState() => NewSessionOptionsSource.aggregate,
  };
}

@Freezed()
sealed class NewSessionState with _$NewSessionState {
  const factory NewSessionState.idle({
    required List<PluginMetadata> availablePlugins,
    required PluginMetadata? selectedPlugin,
    required NewSessionOptionsLoadState options,
    required bool isPluginDiscoveryInFlight,
    required bool supportsDedicatedWorktrees,
  }) = NewSessionIdle;

  const factory NewSessionState.sending({
    required List<PluginMetadata> availablePlugins,
    required PluginMetadata? selectedPlugin,
    required NewSessionOptionsLoadState options,
    required bool isPluginDiscoveryInFlight,
    required bool supportsDedicatedWorktrees,
  }) = NewSessionSending;

  const factory NewSessionState.error({
    required RemoteFailureReason reason,
    required List<PluginMetadata> availablePlugins,
    required PluginMetadata? selectedPlugin,
    required NewSessionOptionsLoadState options,
    required bool isPluginDiscoveryInFlight,
    required bool supportsDedicatedWorktrees,
  }) = NewSessionError;

  const factory NewSessionState.created({required Session session}) = NewSessionCreated;
}

typedef AgentModelData = ({
  List<PluginMetadata> plugins,
  PluginMetadata? plugin,
  NewSessionOptionsLoadState optionsState,
  bool isLoading,
  bool isPluginDiscoveryInFlight,
  List<AgentInfo> agents,
  List<ProviderInfo> providers,
  List<CommandInfo> commands,
  String? agent,
  AgentModel? agentModel,
  CommandInfo? stagedCommand,
  List<SessionVariant> availableVariants,
  bool supportsDedicatedWorktrees,
});

extension NewSessionStateAgentModel on NewSessionState {
  AgentModelData? get agentModelData => switch (this) {
    NewSessionIdle(
      :final availablePlugins,
      :final selectedPlugin,
      :final options,
      :final isPluginDiscoveryInFlight,
      :final supportsDedicatedWorktrees,
    ) =>
      _agentModelData(
        plugins: availablePlugins,
        plugin: selectedPlugin,
        options: options,
        isPluginDiscoveryInFlight: isPluginDiscoveryInFlight,
        supportsDedicatedWorktrees: supportsDedicatedWorktrees,
      ),
    NewSessionSending(
      :final availablePlugins,
      :final selectedPlugin,
      :final options,
      :final isPluginDiscoveryInFlight,
      :final supportsDedicatedWorktrees,
    ) =>
      _agentModelData(
        plugins: availablePlugins,
        plugin: selectedPlugin,
        options: options,
        isPluginDiscoveryInFlight: isPluginDiscoveryInFlight,
        supportsDedicatedWorktrees: supportsDedicatedWorktrees,
      ),
    NewSessionError(
      :final availablePlugins,
      :final selectedPlugin,
      :final options,
      :final isPluginDiscoveryInFlight,
      :final supportsDedicatedWorktrees,
    ) =>
      _agentModelData(
        plugins: availablePlugins,
        plugin: selectedPlugin,
        options: options,
        isPluginDiscoveryInFlight: isPluginDiscoveryInFlight,
        supportsDedicatedWorktrees: supportsDedicatedWorktrees,
      ),
    NewSessionCreated() => null,
  };

  bool get isComposerDataLoading => agentModelData?.isLoading ?? false;
  List<AgentInfo> get availableAgents => agentModelData?.agents ?? const [];
  List<ProviderInfo> get availableProviders => agentModelData?.providers ?? const [];
  List<CommandInfo> get availableCommands => agentModelData?.commands ?? const [];
  String? get selectedAgent => agentModelData?.agent;
  AgentModel? get selectedAgentModel => agentModelData?.agentModel;
  CommandInfo? get stagedCommand => agentModelData?.stagedCommand;
  List<SessionVariant> get availableVariants => agentModelData?.availableVariants ?? const [];
}

AgentModelData _agentModelData({
  required List<PluginMetadata> plugins,
  required PluginMetadata? plugin,
  required NewSessionOptionsLoadState options,
  required bool isPluginDiscoveryInFlight,
  required bool supportsDedicatedWorktrees,
}) {
  final data = options.data;
  return (
    plugins: plugins,
    plugin: plugin,
    optionsState: options,
    isLoading: options.isLoading,
    isPluginDiscoveryInFlight: isPluginDiscoveryInFlight,
    agents: data?.agents ?? const [],
    providers: data?.providers ?? const [],
    commands: data?.commands ?? const [],
    agent: data?.selectedAgent,
    agentModel: data?.selectedAgentModel,
    stagedCommand: data?.stagedCommand,
    availableVariants: data?.availableVariants ?? const [],
    supportsDedicatedWorktrees: supportsDedicatedWorktrees,
  );
}
