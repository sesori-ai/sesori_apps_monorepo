import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "../../services/models/new_session_backend_scope.dart";
import "../../services/models/new_session_options_source.dart";
import "../../services/new_session_options_service.dart";

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
    NewSessionOptionsFailureRetainedState(:final options) => options,
    NewSessionOptionsLoadingState() ||
    NewSessionOptionsUnsupportedState() ||
    NewSessionOptionsUnavailableState() ||
    NewSessionOptionsLoadFailureUnavailableState() ||
    NewSessionOptionsFailureState() ||
    NewSessionOptionsRefreshFailureUnavailableState() => null,
  };

  bool get isLoading => this is NewSessionOptionsLoadingState || this is NewSessionOptionsRefreshingState;

  NewSessionOptionsSource? get source => switch (this) {
    NewSessionOptionsLoadingState(:final source) => source,
    NewSessionOptionsRefreshingState(:final source) ||
    NewSessionOptionsAvailableState(:final source) ||
    NewSessionOptionsFailureState(:final source) ||
    NewSessionOptionsFailureRetainedState(:final source) => source,
    NewSessionOptionsUnsupportedState() => NewSessionOptionsSource.legacy,
    NewSessionOptionsUnavailableState() ||
    NewSessionOptionsLoadFailureUnavailableState() ||
    NewSessionOptionsRefreshFailureUnavailableState() => NewSessionOptionsSource.aggregate,
  };
}

enum NewSessionProjectWorktreeCapability() {
  loading,
  supported,
  unsupported,
  unavailable,
}

@Freezed()
sealed class NewSessionState with _$NewSessionState {
  const factory idle({
    required List<PluginMetadata> availablePlugins,
    required PluginMetadata? selectedPlugin,
    required NewSessionOptionsLoadState options,
    required NewSessionBackendScope backendScope,
    required bool isPluginDiscoveryInFlight,
    required NewSessionProjectWorktreeCapability projectWorktreeCapability,
  }) = NewSessionIdle;

  const factory sending({
    required List<PluginMetadata> availablePlugins,
    required PluginMetadata? selectedPlugin,
    required NewSessionOptionsLoadState options,
    required NewSessionBackendScope backendScope,
    required bool isPluginDiscoveryInFlight,
    required NewSessionProjectWorktreeCapability projectWorktreeCapability,
  }) = NewSessionSending;

  const factory error({
    required RemoteFailureReason reason,
    required List<PluginMetadata> availablePlugins,
    required PluginMetadata? selectedPlugin,
    required NewSessionOptionsLoadState options,
    required NewSessionBackendScope backendScope,
    required bool isPluginDiscoveryInFlight,
    required NewSessionProjectWorktreeCapability projectWorktreeCapability,
  }) = NewSessionError;

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

extension NewSessionStateAgentModel on NewSessionState {
  AgentModelData? get agentModelData => switch (this) {
    NewSessionIdle(
      :final availablePlugins,
      :final selectedPlugin,
      :final options,
      :final backendScope,
      :final isPluginDiscoveryInFlight,
      :final projectWorktreeCapability,
    ) =>
      _agentModelData(
        plugins: availablePlugins,
        plugin: selectedPlugin,
        options: options,
        backendScope: backendScope,
        isPluginDiscoveryInFlight: isPluginDiscoveryInFlight,
        projectWorktreeCapability: projectWorktreeCapability,
      ),
    NewSessionSending(
      :final availablePlugins,
      :final selectedPlugin,
      :final options,
      :final backendScope,
      :final isPluginDiscoveryInFlight,
      :final projectWorktreeCapability,
    ) =>
      _agentModelData(
        plugins: availablePlugins,
        plugin: selectedPlugin,
        options: options,
        backendScope: backendScope,
        isPluginDiscoveryInFlight: isPluginDiscoveryInFlight,
        projectWorktreeCapability: projectWorktreeCapability,
      ),
    NewSessionError(
      :final availablePlugins,
      :final selectedPlugin,
      :final options,
      :final backendScope,
      :final isPluginDiscoveryInFlight,
      :final projectWorktreeCapability,
    ) =>
      _agentModelData(
        plugins: availablePlugins,
        plugin: selectedPlugin,
        options: options,
        backendScope: backendScope,
        isPluginDiscoveryInFlight: isPluginDiscoveryInFlight,
        projectWorktreeCapability: projectWorktreeCapability,
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
  required NewSessionBackendScope backendScope,
  required bool isPluginDiscoveryInFlight,
  required NewSessionProjectWorktreeCapability projectWorktreeCapability,
}) {
  final data = options.data;
  return (
    plugins: plugins,
    plugin: plugin,
    optionsState: options,
    backendScope: backendScope,
    isLoading:
        options.isLoading || projectWorktreeCapability == NewSessionProjectWorktreeCapability.loading,
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
