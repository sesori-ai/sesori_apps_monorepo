import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../services/plugin_management_service.dart";

part "plugin_management_state.freezed.dart";

@Freezed()
sealed class PluginManagementActionError with _$PluginManagementActionError {
  const factory PluginManagementActionError.invalidIdleTimeout() = PluginManagementInvalidIdleTimeout;

  const factory PluginManagementActionError.notFound() = PluginManagementActionNotFound;

  const factory PluginManagementActionError.conflict({
    required PluginLifecycleConflict conflict,
  }) = PluginManagementActionConflict;

  const factory PluginManagementActionError.uncertain() = PluginManagementActionUncertain;

  const factory PluginManagementActionError.request({
    required ApiError error,
  }) = PluginManagementActionRequestError;
}

@Freezed()
sealed class PluginManagementRefreshState with _$PluginManagementRefreshState {
  const factory PluginManagementRefreshState.idle() = PluginManagementRefreshIdle;

  const factory PluginManagementRefreshState.failed({
    required ApiError error,
  }) = PluginManagementRefreshFailed;
}

@Freezed()
sealed class PluginManagementActionTarget with _$PluginManagementActionTarget {
  const factory PluginManagementActionTarget.allHarnesses() = PluginManagementActionTargetAllHarnesses;

  const factory PluginManagementActionTarget.harness({
    required String pluginId,
  }) = PluginManagementActionTargetHarness;
}

@Freezed()
sealed class PluginManagementActionState with _$PluginManagementActionState {
  const factory PluginManagementActionState.idle() = PluginManagementActionIdle;

  const factory PluginManagementActionState.inProgress({
    required PluginManagementActionTarget target,
  }) = PluginManagementActionInProgress;

  const factory PluginManagementActionState.failed({
    required PluginManagementActionTarget target,
    required PluginManagementActionError error,
  }) = PluginManagementActionFailed;

  const factory PluginManagementActionState.forceConfirmationRequired({
    required String pluginId,
    required PluginManagementForceAction action,
    required PluginLifecycleConflict conflict,
    required PluginLifecycleCommandRequest request,
  }) = PluginManagementActionForceConfirmationRequired;
}

@Freezed()
sealed class PluginAuthenticationPresentationError with _$PluginAuthenticationPresentationError {
  const factory PluginAuthenticationPresentationError.notFound() = PluginAuthenticationPresentationNotFound;
  const factory PluginAuthenticationPresentationError.unsupported() = PluginAuthenticationPresentationUnsupported;
  const factory PluginAuthenticationPresentationError.conflict({
    required PluginAuthenticationConflict conflict,
  }) = PluginAuthenticationPresentationConflict;
  const factory PluginAuthenticationPresentationError.uncertain() = PluginAuthenticationPresentationUncertain;
  const factory PluginAuthenticationPresentationError.invalidChallenge() =
      PluginAuthenticationPresentationInvalidChallenge;
  const factory PluginAuthenticationPresentationError.browserLaunchFailed() =
      PluginAuthenticationPresentationBrowserLaunchFailed;
  const factory PluginAuthenticationPresentationError.remote({required String message}) =
      PluginAuthenticationPresentationRemoteError;
  const factory PluginAuthenticationPresentationError.request({required ApiError error}) =
      PluginAuthenticationPresentationRequestError;
}

@Freezed()
sealed class PluginAuthenticationPresentationState with _$PluginAuthenticationPresentationState {
  const factory PluginAuthenticationPresentationState.idle() = PluginAuthenticationPresentationIdle;
  const factory PluginAuthenticationPresentationState.starting({required String pluginId}) =
      PluginAuthenticationPresentationStarting;
  const factory PluginAuthenticationPresentationState.challenge({
    required String pluginId,
    required Uri verificationUri,
    required String userCode,
  }) = PluginAuthenticationPresentationChallenge;
  const factory PluginAuthenticationPresentationState.browserLaunchFailed({
    required String pluginId,
    required Uri verificationUri,
    required String userCode,
  }) = PluginAuthenticationPresentationBrowserLaunchFailedState;
  const factory PluginAuthenticationPresentationState.cancelling({
    required String pluginId,
    required Uri verificationUri,
    required String userCode,
  }) = PluginAuthenticationPresentationCancelling;
  const factory PluginAuthenticationPresentationState.cancellingUncertain({
    required String pluginId,
    required Uri verificationUri,
    required String userCode,
  }) = PluginAuthenticationPresentationCancellingUncertain;
  const factory PluginAuthenticationPresentationState.failed({
    required String? pluginId,
    required PluginAuthenticationPresentationError error,
  }) = PluginAuthenticationPresentationFailed;
}

@Freezed()
sealed class PluginManagementState with _$PluginManagementState {
  const factory PluginManagementState.loading() = PluginManagementLoading;

  const factory PluginManagementState.unsupported() = PluginManagementUnsupported;

  const factory PluginManagementState.failure({required ApiError error}) = PluginManagementFailure;

  const factory PluginManagementState.ready({
    required PluginManagementResponse response,
    required PluginManagementRefreshState refresh,
    required PluginManagementActionState action,
    required PluginAuthenticationPresentationState authentication,

    /// In-flight managed runtime installs, keyed by plugin id.
    required Map<String, PluginInstallProgress> installs,
  }) = PluginManagementReady;
}
