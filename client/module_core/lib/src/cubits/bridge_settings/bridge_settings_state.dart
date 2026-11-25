import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const BridgeSettingsState();

final class const BridgeSettingsLoading({
  /// Whether the last loaded settings reported a release track, so its row
  /// can wait out the load instead of closing.
  required final bool hasReleaseTrack,
}) extends BridgeSettingsState;

final class const BridgeSettingsDisconnected({
  /// Whether the last loaded settings reported a release track.
  required final bool hasReleaseTrack,
}) extends BridgeSettingsState;

final class const BridgeSettingsUnsupported() extends BridgeSettingsState;

final class const BridgeSettingsFailure({
  required final ApiError error,

  /// Whether the last loaded settings reported a release track.
  required final bool hasReleaseTrack,
}) extends BridgeSettingsState;

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
