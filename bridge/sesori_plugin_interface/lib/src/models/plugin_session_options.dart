import "package:freezed_annotation/freezed_annotation.dart";

import "plugin_agent.dart";
import "plugin_command.dart";
import "plugin_provider.dart";

part "plugin_session_options.freezed.dart";

enum PluginSessionOptionsCompleteness() {
  partial,
  complete,
}

enum PluginSessionOptionsDiscoveryMode() {
  reuse,
  refresh,
}

@Freezed(toJson: false)
sealed class PluginSessionOptions with _$PluginSessionOptions {
  const factory({
    required List<PluginAgent> agents,
    required PluginProvidersResult providers,
    required List<PluginCommand> commands,
    required PluginSessionOptionsCompleteness completeness,
  }) = _PluginSessionOptions;
}

@Freezed(toJson: false)
sealed class PluginSessionOptionsDiscoveryResult with _$PluginSessionOptionsDiscoveryResult {
  const factory observed({
    required PluginSessionOptions options,
  }) = PluginSessionOptionsDiscoveryObserved;

  /// The requested option scope has no authenticated provider/model available.
  ///
  /// This is scoped to this discovery request. It must not be used for
  /// plugin-global authentication loss, which is reported through
  /// `PluginAuthenticationRequiredException`. [actionHint] is plugin-owned,
  /// privacy-safe presentation text and must never contain raw backend output,
  /// credential details, account identifiers, or local paths.
  const factory authenticationRequired({
    required String actionHint,
  }) = PluginSessionOptionsDiscoveryAuthenticationRequired;

  const factory failed() = PluginSessionOptionsDiscoveryFailed;
}
