import "package:freezed_annotation/freezed_annotation.dart";

import "plugin_agent.dart";
import "plugin_command.dart";
import "plugin_provider.dart";

part "plugin_session_options.freezed.dart";

enum PluginSessionOptionsCompleteness { partial, complete }

enum PluginSessionOptionsDiscoveryMode { reuse, refresh }

@Freezed(toJson: false)
sealed class PluginSessionOptions with _$PluginSessionOptions {
  const factory PluginSessionOptions({
    required List<PluginAgent> agents,
    required PluginProvidersResult providers,
    required List<PluginCommand> commands,
    required PluginSessionOptionsCompleteness completeness,
  }) = _PluginSessionOptions;
}

@Freezed(toJson: false)
sealed class PluginSessionOptionsDiscoveryResult with _$PluginSessionOptionsDiscoveryResult {
  const factory PluginSessionOptionsDiscoveryResult.observed({
    required PluginSessionOptions options,
  }) = PluginSessionOptionsDiscoveryObserved;

  const factory PluginSessionOptionsDiscoveryResult.failed() = PluginSessionOptionsDiscoveryFailed;
}
