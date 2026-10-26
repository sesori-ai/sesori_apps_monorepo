import "package:sesori_auth/sesori_auth.dart";

sealed class const BridgeSettingsState();

final class const BridgeSettingsLoading() extends BridgeSettingsState;

final class const BridgeSettingsDisconnected() extends BridgeSettingsState;

final class const BridgeSettingsUnsupported() extends BridgeSettingsState;

final class const BridgeSettingsFailure({required final ApiError error}) extends BridgeSettingsState;

final class const BridgeSettingsReady({
  required final bool yoloEnabled,
  required final YoloMutationState yoloMutation,
  required final PluginWarmupMutationState pluginWarmupMutation,
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
