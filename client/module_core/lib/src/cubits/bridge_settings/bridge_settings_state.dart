import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../repositories/models/bridge_settings_result.dart";

sealed class const BridgeSettingsState();

final class const BridgeSettingsLoading({required final ReportedOptionalSettings reported}) extends BridgeSettingsState;

final class const BridgeSettingsDisconnected({required final ReportedOptionalSettings reported})
    extends BridgeSettingsState;

final class const BridgeSettingsUnsupported() extends BridgeSettingsState;

final class const BridgeSettingsFailure({
  required final ApiError error,
  required final ReportedOptionalSettings reported,
}) extends BridgeSettingsState;

/// Which optional settings the last loaded settings reported, carried through
/// a reload, a failed load or a dropped connection so their rows can wait
/// instead of closing.
final class const ReportedOptionalSettings({required final bool releaseTrack, required final bool preventSleep}) {
  static const none = ReportedOptionalSettings(releaseTrack: false, preventSleep: false);
}

final class const BridgeSettingsReady({
  required final bool yoloEnabled,
  required final YoloMutationState yoloMutation,
  required final PluginWarmupMutationState pluginWarmupMutation,

  /// Null for a bridge without agent-tools settings, which leaves the
  /// section out.
  required final AgentToolsSettings? agentTools,

  /// Null for a bridge that does not update itself or predates the setting,
  /// which leaves it out.
  required final ReleaseTrackSettings? releaseTrack,

  /// Null for a bridge that predates the setting, which leaves it out.
  required final PreventSleepSettings? preventSleep,
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

/// The release channel of a bridge that updates itself: stable releases
/// only, or internal pre-releases too. A change applies from the bridge's
/// next start.
final class const ReleaseTrackSettings({
  required final bool internalBuilds,
  required final ReleaseTrackMutationState mutation,
});

sealed class const ReleaseTrackMutationState();

final class const ReleaseTrackMutationIdle() extends ReleaseTrackMutationState;

final class const ReleaseTrackMutationInProgress() extends ReleaseTrackMutationState;

final class const ReleaseTrackMutationFailed({required final ApiError error}) extends ReleaseTrackMutationState;

/// A save whose outcome is unknown, and the reload after it failed too.
final class const ReleaseTrackMutationUncertain({required final ApiError refreshError})
    extends ReleaseTrackMutationState;

/// Whether the bridge keeps its computer from going to sleep. A change
/// applies right away.
final class const PreventSleepSettings({
  required final PreventSleepStatus status,
  required final PreventSleepMutationState mutation,
}) {
  /// The stored choice, whether or not the wake lock holds.
  bool get enabled => status != PreventSleepStatus.off;
}

sealed class const PreventSleepMutationState();

final class const PreventSleepMutationIdle() extends PreventSleepMutationState;

final class const PreventSleepMutationInProgress() extends PreventSleepMutationState;

final class const PreventSleepMutationFailed({required final ApiError error}) extends PreventSleepMutationState;

/// A save whose outcome is unknown, and the reload after it failed too.
final class const PreventSleepMutationUncertain({required final ApiError refreshError})
    extends PreventSleepMutationState;
