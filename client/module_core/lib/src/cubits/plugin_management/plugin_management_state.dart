import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../repositories/models/plugin_management_result.dart";
import "../../services/models/catalog_rescan_state.dart";
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

sealed class const PluginAuthenticationChallengePresentation() {
  const factory deviceCode({required PluginAuthenticationDeviceCodeChallenge challenge}) =
      PluginAuthenticationDeviceCodePresentation;
  const factory browser({required PluginAuthenticationBrowserChallenge challenge}) =
      PluginAuthenticationBrowserPresentation;
  const factory updateRequired({required PluginAuthenticationUnsupportedChallenge challenge}) =
      PluginAuthenticationUpdateRequiredPresentation;
  const factory invalidRedirect({required PluginAuthenticationBrowserChallenge challenge}) =
      PluginAuthenticationInvalidRedirectPresentation;
  const factory redirectSubmitting({required PluginAuthenticationBrowserChallenge challenge}) =
      PluginAuthenticationRedirectSubmittingPresentation;
  const factory redirectSubmitted({required PluginAuthenticationBrowserChallenge challenge}) =
      PluginAuthenticationRedirectSubmittedPresentation;

  PluginAuthenticationChallenge get challenge;
}

final class const PluginAuthenticationDeviceCodePresentation({
  @override required final PluginAuthenticationDeviceCodeChallenge challenge,
}) extends PluginAuthenticationChallengePresentation;
final class const PluginAuthenticationBrowserPresentation({
  @override required final PluginAuthenticationBrowserChallenge challenge,
}) extends PluginAuthenticationChallengePresentation;
final class const PluginAuthenticationUpdateRequiredPresentation({
  @override required final PluginAuthenticationUnsupportedChallenge challenge,
}) extends PluginAuthenticationChallengePresentation;
final class const PluginAuthenticationInvalidRedirectPresentation({
  @override required final PluginAuthenticationBrowserChallenge challenge,
}) extends PluginAuthenticationChallengePresentation;
final class const PluginAuthenticationRedirectSubmittingPresentation({
  @override required final PluginAuthenticationBrowserChallenge challenge,
}) extends PluginAuthenticationChallengePresentation;
final class const PluginAuthenticationRedirectSubmittedPresentation({
  @override required final PluginAuthenticationBrowserChallenge challenge,
}) extends PluginAuthenticationChallengePresentation;

@Freezed()
sealed class PluginAuthenticationPresentationState with _$PluginAuthenticationPresentationState {
  const factory idle() = PluginAuthenticationPresentationIdle;
  const factory starting({required String pluginId}) = PluginAuthenticationPresentationStarting;
  const factory challenge({
    required String pluginId,
    required PluginAuthenticationChallengePresentation challenge,
  }) = PluginAuthenticationPresentationChallenge;
  const factory browserLaunchFailed({
    required String pluginId,
    required PluginAuthenticationChallenge challenge,
  }) = PluginAuthenticationPresentationBrowserLaunchFailedState;
  const factory cancelling({
    required String pluginId,
    required PluginAuthenticationChallenge challenge,
  }) = PluginAuthenticationPresentationCancelling;
  const factory cancellingUncertain({
    required String pluginId,
    required PluginAuthenticationChallenge challenge,
  }) = PluginAuthenticationPresentationCancellingUncertain;
  const factory failed({
    required String? pluginId,
    required PluginAuthenticationPresentationError error,
  }) = PluginAuthenticationPresentationFailed;
}

/// How a catalog scan this screen started actually ended.
///
/// Only the three outcomes a *started* scan can reach. A bridge that refused
/// the start never gets here: that answer is a [CatalogRescanStartResult] and
/// belongs on the harness card, which is where the user aimed the request.
@Freezed()
sealed class CatalogRescanOutcome with _$CatalogRescanOutcome {
  const factory succeeded({required CatalogRescanCounts counts}) = CatalogRescanOutcomeSucceeded;

  const factory partlyFailed({
    required int succeededCount,
    required int failedCount,
  }) = CatalogRescanOutcomePartlyFailed;

  const factory failed() = CatalogRescanOutcomeFailed;
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

    /// Harnesses with a catalog scan in flight, whether this screen started it
    /// or the lists did. Their scan action is not offered again while it runs.
    required Set<String> scanningPluginIds,

    /// Why a targeted scan was turned down, keyed by the harness the user
    /// named. An accepted start is never recorded: the card reports it by
    /// disabling its own action, and the aggregate row reports the run.
    required Map<String, CatalogRescanStartResult> scanRejections,

    /// How a scan started from this screen ended, held until it is reported.
    ///
    /// This screen hosts no progress row, so a scan started here would
    /// otherwise finish in silence: the spinner simply stops, and the result
    /// the service published is auto-cleared before the user could reach a
    /// list to read it.
    required CatalogRescanOutcome? scanOutcome,
  }) = PluginManagementReady;
}
