import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const BridgeSettingsLoadResult();

final class const BridgeSettingsLoadSupported({required final BridgeSettingsResponse response})
    extends BridgeSettingsLoadResult;

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
