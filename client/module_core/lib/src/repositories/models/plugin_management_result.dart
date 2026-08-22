import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const PluginManagementLoadResult() {
  const factory loading() = PluginManagementLoadResultLoading;

  const factory supported({
    required PluginManagementResponse response,
    required ApiError? refreshError,
  }) = PluginManagementLoadResultSupported;

  const factory unsupported() = PluginManagementLoadResultUnsupported;

  const factory failure({required ApiError error}) = PluginManagementLoadResultFailure;
}

final class const PluginManagementLoadResultLoading() extends PluginManagementLoadResult;

final class const PluginManagementLoadResultSupported({
  required final PluginManagementResponse response,

  /// Non-null when this publication replays a retained snapshot after a
  /// refresh failure against the same bridge identity.
  required final ApiError? refreshError,
}) extends PluginManagementLoadResult;

final class const PluginManagementLoadResultUnsupported() extends PluginManagementLoadResult;

final class const PluginManagementLoadResultFailure({required final ApiError error})
    extends PluginManagementLoadResult;

sealed class const PluginManagementMutationResult() {
  const factory success({
    required PluginManagementResponse response,
  }) = PluginManagementMutationResultSuccess;

  const factory notFound() = PluginManagementMutationResultNotFound;

  const factory conflict({
    required PluginLifecycleConflict conflict,
  }) = PluginManagementMutationResultConflict;

  /// The mutation request was sent but its outcome cannot be truthfully
  /// published: the response cannot prove it or the connection/service fence
  /// moved. Consumers render this as an uncertain state requiring refresh,
  /// never as a bridge rejection or a committed success.
  const factory uncertain() = PluginManagementMutationResultUncertain;

  const factory failure({required ApiError error}) = PluginManagementMutationResultFailure;
}

final class const PluginManagementMutationResultSuccess({required final PluginManagementResponse response})
    extends PluginManagementMutationResult;

final class const PluginManagementMutationResultNotFound() extends PluginManagementMutationResult;

final class const PluginManagementMutationResultConflict({required final PluginLifecycleConflict conflict})
    extends PluginManagementMutationResult;

final class const PluginManagementMutationResultUncertain() extends PluginManagementMutationResult;

final class const PluginManagementMutationResultFailure({required final ApiError error})
    extends PluginManagementMutationResult;

/// Why a plugin authentication start or cancel did not succeed.
///
/// Start and cancel fail in exactly the same ways, so they share one failure
/// type rather than each declaring its own five-variant copy.
sealed class const PluginAuthenticationFailure() {
  /// The bridge does not know this plugin.
  const factory notFound() = PluginAuthenticationFailureNotFound;

  /// The plugin's lifecycle forbids the request right now.
  const factory conflict({
    required PluginAuthenticationConflict conflict,
  }) = PluginAuthenticationFailureConflict;

  /// This plugin does not support interactive authentication.
  const factory unsupported() = PluginAuthenticationFailureUnsupported;

  /// The request may or may not have reached the bridge, so the caller must
  /// not assume either outcome.
  const factory uncertain() = PluginAuthenticationFailureUncertain;

  /// Any other transport or protocol failure, carrying its cause.
  const factory request({required ApiError error}) = PluginAuthenticationFailureRequest;
}

final class const PluginAuthenticationFailureNotFound() extends PluginAuthenticationFailure;

final class const PluginAuthenticationFailureConflict({required final PluginAuthenticationConflict conflict})
    extends PluginAuthenticationFailure;

final class const PluginAuthenticationFailureUnsupported() extends PluginAuthenticationFailure;

final class const PluginAuthenticationFailureUncertain() extends PluginAuthenticationFailure;

final class const PluginAuthenticationFailureRequest({required final ApiError error})
    extends PluginAuthenticationFailure;

sealed class const PluginAuthenticationStartResult() {
  const factory challenge({
    required PluginAuthenticationChallengeResponse challenge,
  }) = PluginAuthenticationStartChallenge;

  const factory failed({
    required PluginAuthenticationFailure failure,
  }) = PluginAuthenticationStartFailed;
}

final class const PluginAuthenticationStartChallenge({required final PluginAuthenticationChallengeResponse challenge})
    extends PluginAuthenticationStartResult;

final class const PluginAuthenticationStartFailed({required final PluginAuthenticationFailure failure})
    extends PluginAuthenticationStartResult;

sealed class const PluginAuthenticationCancelResult() {
  const factory success() = PluginAuthenticationCancelSuccess;

  const factory failed({
    required PluginAuthenticationFailure failure,
  }) = PluginAuthenticationCancelFailed;
}

final class const PluginAuthenticationCancelSuccess() extends PluginAuthenticationCancelResult;

final class const PluginAuthenticationCancelFailed({required final PluginAuthenticationFailure failure})
    extends PluginAuthenticationCancelResult;
