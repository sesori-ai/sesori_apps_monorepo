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
