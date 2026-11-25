import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const BridgeSettingsLoadResult();

final class const BridgeSettingsLoadSupported({required final BridgeSettingsResponse response})
    extends BridgeSettingsLoadResult {
  /// Whether the bridge's auto-updater also takes internal pre-releases, or
  /// null when it reports no track or one this app does not know.
  bool? get releaseTrackInternalBuilds => switch (response.releaseTrack) {
    BridgeReleaseTrack.stable => false,
    BridgeReleaseTrack.internal => true,
    BridgeReleaseTrack.unknown || null => null,
  };

  /// Whether the bridge keeps its computer awake, or null when it does not
  /// report the setting or reports a status this app does not know.
  PreventSleepStatus? get preventSleepStatus => switch (response.preventSleep) {
    SleepPreventionStatus.off => PreventSleepStatus.off,
    SleepPreventionStatus.awake => PreventSleepStatus.awake,
    SleepPreventionStatus.failed => PreventSleepStatus.failed,
    SleepPreventionStatus.unknown || null => null,
  };
}

/// Whether the bridge keeps its computer from going to sleep.
enum PreventSleepStatus() {
  /// The computer may sleep.
  off,

  /// The bridge keeps the computer awake.
  awake,

  /// The choice is on, but the computer refused the wake lock and can still
  /// sleep.
  failed,
}

final class const BridgeSettingsLoadUnsupported() extends BridgeSettingsLoadResult;

final class const BridgeSettingsLoadFailure({required final ApiError error}) extends BridgeSettingsLoadResult;

sealed class const YoloSettingsMutationResult();

final class const YoloSettingsMutationCommitted({required final YoloSettingsResponse response})
    extends YoloSettingsMutationResult;

final class const YoloSettingsMutationUnsupported() extends YoloSettingsMutationResult;

final class const YoloSettingsMutationUncertain() extends YoloSettingsMutationResult;

final class const YoloSettingsMutationFailure({required final ApiError error}) extends YoloSettingsMutationResult;

sealed class const PluginWarmupSettingsMutationResult();

final class const PluginWarmupSettingsMutationCommitted({required final bool enabled})
    extends PluginWarmupSettingsMutationResult;

final class const PluginWarmupSettingsMutationUnsupported() extends PluginWarmupSettingsMutationResult;

final class const PluginWarmupSettingsMutationUncertain() extends PluginWarmupSettingsMutationResult;

final class const PluginWarmupSettingsMutationFailure({required final ApiError error})
    extends PluginWarmupSettingsMutationResult;

/// The outcome of turning Sesori's tools, or one of their groups, on or off.
sealed class const AgentToolsSettingsMutationResult();

/// The bridge's committed state of the switch that was changed.
final class const AgentToolsSettingsMutationCommitted({required final bool enabled})
    extends AgentToolsSettingsMutationResult;

final class const AgentToolsSettingsMutationUncertain() extends AgentToolsSettingsMutationResult;

final class const AgentToolsSettingsMutationFailure({required final ApiError error})
    extends AgentToolsSettingsMutationResult;

/// The outcome of setting the bridge's release track.
sealed class const ReleaseTrackSettingsMutationResult();

/// The bridge's committed track: internal pre-releases too, or stable only.
final class const ReleaseTrackSettingsMutationCommitted({required final bool internalBuilds})
    extends ReleaseTrackSettingsMutationResult;

final class const ReleaseTrackSettingsMutationUncertain() extends ReleaseTrackSettingsMutationResult;

final class const ReleaseTrackSettingsMutationFailure({required final ApiError error})
    extends ReleaseTrackSettingsMutationResult;

/// The outcome of keeping the bridge's computer awake, or letting it sleep.
sealed class const PreventSleepSettingsMutationResult();

/// The bridge's committed choice.
final class const PreventSleepSettingsMutationCommitted({required final bool enabled})
    extends PreventSleepSettingsMutationResult;

final class const PreventSleepSettingsMutationUncertain() extends PreventSleepSettingsMutationResult;

final class const PreventSleepSettingsMutationFailure({required final ApiError error})
    extends PreventSleepSettingsMutationResult;
