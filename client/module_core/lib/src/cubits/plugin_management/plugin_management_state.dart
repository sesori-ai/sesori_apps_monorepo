import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../services/plugin_management_service.dart";

part "plugin_management_state.freezed.dart";

@Freezed()
sealed class PluginManagementActionError with _$PluginManagementActionError {
  const factory invalidIdleTimeout() = PluginManagementInvalidIdleTimeout;

  const factory notFound() = PluginManagementActionNotFound;

  const factory conflict({
    required PluginLifecycleConflict conflict,
  }) = PluginManagementActionConflict;

  const factory uncertain() = PluginManagementActionUncertain;

  const factory request({
    required ApiError error,
  }) = PluginManagementActionRequestError;
}

@Freezed()
sealed class PluginManagementRefreshState with _$PluginManagementRefreshState {
  const factory idle() = PluginManagementRefreshIdle;

  const factory failed({
    required ApiError error,
  }) = PluginManagementRefreshFailed;
}

@Freezed()
sealed class PluginManagementActionTarget with _$PluginManagementActionTarget {
  const factory allHarnesses() = PluginManagementActionTargetAllHarnesses;

  const factory harness({
    required String pluginId,
  }) = PluginManagementActionTargetHarness;
}

@Freezed()
sealed class PluginManagementActionState with _$PluginManagementActionState {
  const factory idle() = PluginManagementActionIdle;

  const factory inProgress({
    required PluginManagementActionTarget target,
  }) = PluginManagementActionInProgress;

  const factory failed({
    required PluginManagementActionTarget target,
    required PluginManagementActionError error,
  }) = PluginManagementActionFailed;

  const factory forceConfirmationRequired({
    required String pluginId,
    required PluginManagementForceAction action,
    required PluginLifecycleConflict conflict,
    required PluginLifecycleCommandRequest request,
  }) = PluginManagementActionForceConfirmationRequired;
}

@Freezed()
sealed class PluginAuthenticationPresentationError with _$PluginAuthenticationPresentationError {
  const factory notFound() = PluginAuthenticationPresentationNotFound;
  const factory unsupported() = PluginAuthenticationPresentationUnsupported;
  const factory conflict({
    required PluginAuthenticationConflict conflict,
  }) = PluginAuthenticationPresentationConflict;
  const factory uncertain() = PluginAuthenticationPresentationUncertain;
  const factory invalidChallenge() = PluginAuthenticationPresentationInvalidChallenge;
  const factory remote({required String message}) = PluginAuthenticationPresentationRemoteError;
  const factory request({required ApiError error}) = PluginAuthenticationPresentationRequestError;
}

@Freezed()
sealed class PluginAuthenticationPresentationState with _$PluginAuthenticationPresentationState {
  const factory idle() = PluginAuthenticationPresentationIdle;
  const factory starting({required String pluginId}) = PluginAuthenticationPresentationStarting;
  const factory challenge({
    required String pluginId,
    required Uri verificationUri,
    required String userCode,
  }) = PluginAuthenticationPresentationChallenge;
  const factory browserLaunchFailed({
    required String pluginId,
    required Uri verificationUri,
    required String userCode,
  }) = PluginAuthenticationPresentationBrowserLaunchFailedState;
  const factory cancelling({
    required String pluginId,
    required Uri verificationUri,
    required String userCode,
  }) = PluginAuthenticationPresentationCancelling;
  const factory cancellingUncertain({
    required String pluginId,
    required Uri verificationUri,
    required String userCode,
  }) = PluginAuthenticationPresentationCancellingUncertain;
  const factory failed({
    required String? pluginId,
    required PluginAuthenticationPresentationError error,
  }) = PluginAuthenticationPresentationFailed;
}

@Freezed()
sealed class PluginManagementState with _$PluginManagementState {
  const factory loading() = PluginManagementLoading;

  const factory unsupported() = PluginManagementUnsupported;

  const factory failure({required ApiError error}) = PluginManagementFailure;

  const factory ready({
    required PluginManagementResponse response,
    required PluginManagementRefreshState refresh,
    required PluginManagementActionState action,
    required PluginAuthenticationPresentationState authentication,

    /// In-flight managed runtime installs, keyed by plugin id.
    required Map<String, PluginInstallProgress> installs,
  }) = PluginManagementReady;
}
