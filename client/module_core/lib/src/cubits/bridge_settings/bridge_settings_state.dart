import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const BridgeSettingsState();

final class const BridgeSettingsLoading() extends BridgeSettingsState;

final class const BridgeSettingsDisconnected() extends BridgeSettingsState;

final class const BridgeSettingsUnsupported() extends BridgeSettingsState;

final class const BridgeSettingsFailure({required final ApiError error}) extends BridgeSettingsState;

final class const BridgeSettingsReady({
  required final bool yoloEnabled,
  required final YoloMutationState yoloMutation,
  required final PluginWarmupMutationState pluginWarmupMutation,

  /// Null for a bridge without agent-tools settings, which leaves the
  /// section out.
  required final AgentToolsSettings? agentTools,
}) extends BridgeSettingsState;

sealed class const YoloMutationState();

final class const YoloMutationIdle() extends YoloMutationState;

final class const YoloMutationInProgress() extends YoloMutationState;

final class const YoloMutationFailed({required final ApiError error}) extends YoloMutationState;

final class const YoloMutationUncertain({required final ApiError refreshError}) extends YoloMutationState;

final class const YoloMutationUnsupported() extends YoloMutationState;

sealed class const PluginWarmupMutationState();

final class const PluginWarmupMutationIdle({required final bool enabled}) extends PluginWarmupMutationState;

final class const PluginWarmupMutationInProgress({required final bool enabled}) extends PluginWarmupMutationState;

final class const PluginWarmupMutationFailed({
  required final bool enabled,
  required final ApiError error,
}) extends PluginWarmupMutationState;

final class const PluginWarmupMutationUncertain({
  required final bool enabled,
  required final ApiError refreshError,
}) extends PluginWarmupMutationState;

final class const PluginWarmupMutationUnsupported() extends PluginWarmupMutationState;

/// Sesori's tools on the bridge: the master switch, and each group's own
/// switch, which keeps its state while the master is off.
final class const AgentToolsSettings({
  required final bool enabled,
  required final List<BridgeToolGroupSetting> groups,
  required final AgentToolsMutationState mutation,
});

/// One of the section's switches.
sealed class const AgentToolsSwitch();

final class const AgentToolsMasterSwitch() extends AgentToolsSwitch;

final class const AgentToolGroupSwitch({required final String id}) extends AgentToolsSwitch;

sealed class const AgentToolsMutationState();

final class const AgentToolsMutationIdle() extends AgentToolsMutationState;

final class const AgentToolsMutationInProgress({required final AgentToolsSwitch target})
    extends AgentToolsMutationState;

final class const AgentToolsMutationFailed({
  required final AgentToolsSwitch target,
  required final ApiError error,
}) extends AgentToolsMutationState;

/// A save whose outcome is unknown, and the reload after it failed too.
final class const AgentToolsMutationUncertain({required final ApiError refreshError}) extends AgentToolsMutationState;

/// The bridge refused the change as a setting it does not know.
final class const AgentToolsMutationUnsupported() extends AgentToolsMutationState;
