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

sealed class const PluginAuthenticationStartResult() {
  const factory challenge({
    required PluginAuthenticationChallengeResponse challenge,
  }) = PluginAuthenticationStartChallenge;

  const factory notFound() = PluginAuthenticationStartNotFound;

  const factory conflict({
    required PluginAuthenticationConflict conflict,
  }) = PluginAuthenticationStartConflict;

  const factory unsupported() = PluginAuthenticationStartUnsupported;

  const factory uncertain() = PluginAuthenticationStartUncertain;

  const factory failure({required ApiError error}) = PluginAuthenticationStartFailure;
}

final class const PluginAuthenticationStartChallenge({required final PluginAuthenticationChallengeResponse challenge})
    extends PluginAuthenticationStartResult;

final class const PluginAuthenticationStartNotFound() extends PluginAuthenticationStartResult;

final class const PluginAuthenticationStartConflict({required final PluginAuthenticationConflict conflict})
    extends PluginAuthenticationStartResult;

final class const PluginAuthenticationStartUnsupported() extends PluginAuthenticationStartResult;

final class const PluginAuthenticationStartUncertain() extends PluginAuthenticationStartResult;

final class const PluginAuthenticationStartFailure({required final ApiError error})
    extends PluginAuthenticationStartResult;

sealed class const PluginAuthenticationCancelResult() {
  const factory success() = PluginAuthenticationCancelSuccess;
  const factory notFound() = PluginAuthenticationCancelNotFound;
  const factory conflict({
    required PluginAuthenticationConflict conflict,
  }) = PluginAuthenticationCancelConflict;
  const factory unsupported() = PluginAuthenticationCancelUnsupported;
  const factory uncertain() = PluginAuthenticationCancelUncertain;
  const factory failure({required ApiError error}) = PluginAuthenticationCancelFailure;
}

final class const PluginAuthenticationCancelSuccess() extends PluginAuthenticationCancelResult;

final class const PluginAuthenticationCancelNotFound() extends PluginAuthenticationCancelResult;

final class const PluginAuthenticationCancelConflict({required final PluginAuthenticationConflict conflict})
    extends PluginAuthenticationCancelResult;

final class const PluginAuthenticationCancelUnsupported() extends PluginAuthenticationCancelResult;

final class const PluginAuthenticationCancelUncertain() extends PluginAuthenticationCancelResult;

final class const PluginAuthenticationCancelFailure({required final ApiError error})
    extends PluginAuthenticationCancelResult;
