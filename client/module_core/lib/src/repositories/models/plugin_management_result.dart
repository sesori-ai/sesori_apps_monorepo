import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const PluginManagementLoadResult() {
  const factory PluginManagementLoadResult.loading() = PluginManagementLoadResultLoading;

  const factory PluginManagementLoadResult.supported({
    required PluginManagementResponse response,
    required ApiError? refreshError,
  }) = PluginManagementLoadResultSupported;

  const factory PluginManagementLoadResult.unsupported() = PluginManagementLoadResultUnsupported;

  const factory PluginManagementLoadResult.failure({required ApiError error}) = PluginManagementLoadResultFailure;
}

final class const PluginManagementLoadResultLoading() extends PluginManagementLoadResult;

final class const PluginManagementLoadResultSupported({required this.response, required this.refreshError}) extends PluginManagementLoadResult {
  final PluginManagementResponse response;

  /// Non-null when this publication replays a retained snapshot after a
  /// refresh failure against the same bridge identity.
  final ApiError? refreshError;
}

final class const PluginManagementLoadResultUnsupported() extends PluginManagementLoadResult;

final class const PluginManagementLoadResultFailure({required this.error}) extends PluginManagementLoadResult {
  final ApiError error;
}

sealed class const PluginManagementMutationResult() {
  const factory PluginManagementMutationResult.success({
    required PluginManagementResponse response,
  }) = PluginManagementMutationResultSuccess;

  const factory PluginManagementMutationResult.notFound() = PluginManagementMutationResultNotFound;

  const factory PluginManagementMutationResult.conflict({
    required PluginLifecycleConflict conflict,
  }) = PluginManagementMutationResultConflict;

  /// The mutation request was sent but its outcome cannot be truthfully
  /// published: the response cannot prove it or the connection/service fence
  /// moved. Consumers render this as an uncertain state requiring refresh,
  /// never as a bridge rejection or a committed success.
  const factory PluginManagementMutationResult.uncertain() = PluginManagementMutationResultUncertain;

  const factory PluginManagementMutationResult.failure({required ApiError error}) =
      PluginManagementMutationResultFailure;
}

final class const PluginManagementMutationResultSuccess({required this.response}) extends PluginManagementMutationResult {
  final PluginManagementResponse response;
}

final class const PluginManagementMutationResultNotFound() extends PluginManagementMutationResult;

final class const PluginManagementMutationResultConflict({required this.conflict}) extends PluginManagementMutationResult {
  final PluginLifecycleConflict conflict;
}

final class const PluginManagementMutationResultUncertain() extends PluginManagementMutationResult;

final class const PluginManagementMutationResultFailure({required this.error}) extends PluginManagementMutationResult {
  final ApiError error;
}

sealed class const PluginAuthenticationStartResult() {
  const factory PluginAuthenticationStartResult.challenge({
    required PluginAuthenticationChallengeResponse challenge,
  }) = PluginAuthenticationStartChallenge;

  const factory PluginAuthenticationStartResult.notFound() = PluginAuthenticationStartNotFound;

  const factory PluginAuthenticationStartResult.conflict({
    required PluginAuthenticationConflict conflict,
  }) = PluginAuthenticationStartConflict;

  const factory PluginAuthenticationStartResult.unsupported() = PluginAuthenticationStartUnsupported;

  const factory PluginAuthenticationStartResult.uncertain() = PluginAuthenticationStartUncertain;

  const factory PluginAuthenticationStartResult.failure({required ApiError error}) = PluginAuthenticationStartFailure;
}

final class const PluginAuthenticationStartChallenge({required this.challenge}) extends PluginAuthenticationStartResult {
  final PluginAuthenticationChallengeResponse challenge;
}

final class const PluginAuthenticationStartNotFound() extends PluginAuthenticationStartResult;

final class const PluginAuthenticationStartConflict({required this.conflict}) extends PluginAuthenticationStartResult {
  final PluginAuthenticationConflict conflict;
}

final class const PluginAuthenticationStartUnsupported() extends PluginAuthenticationStartResult;

final class const PluginAuthenticationStartUncertain() extends PluginAuthenticationStartResult;

final class const PluginAuthenticationStartFailure({required this.error}) extends PluginAuthenticationStartResult {
  final ApiError error;
}

sealed class const PluginAuthenticationCancelResult() {
  const factory PluginAuthenticationCancelResult.success() = PluginAuthenticationCancelSuccess;
  const factory PluginAuthenticationCancelResult.notFound() = PluginAuthenticationCancelNotFound;
  const factory PluginAuthenticationCancelResult.conflict({
    required PluginAuthenticationConflict conflict,
  }) = PluginAuthenticationCancelConflict;
  const factory PluginAuthenticationCancelResult.unsupported() = PluginAuthenticationCancelUnsupported;
  const factory PluginAuthenticationCancelResult.uncertain() = PluginAuthenticationCancelUncertain;
  const factory PluginAuthenticationCancelResult.failure({required ApiError error}) = PluginAuthenticationCancelFailure;
}

final class const PluginAuthenticationCancelSuccess() extends PluginAuthenticationCancelResult;

final class const PluginAuthenticationCancelNotFound() extends PluginAuthenticationCancelResult;

final class const PluginAuthenticationCancelConflict({required this.conflict}) extends PluginAuthenticationCancelResult {
  final PluginAuthenticationConflict conflict;
}

final class const PluginAuthenticationCancelUnsupported() extends PluginAuthenticationCancelResult;

final class const PluginAuthenticationCancelUncertain() extends PluginAuthenticationCancelResult;

final class const PluginAuthenticationCancelFailure({required this.error}) extends PluginAuthenticationCancelResult {
  final ApiError error;
}
