import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class PluginManagementLoadResult {
  const PluginManagementLoadResult();

  const factory PluginManagementLoadResult.supported({
    required PluginManagementResponse response,
    required ApiError? refreshError,
  }) = PluginManagementLoadResultSupported;

  const factory PluginManagementLoadResult.unsupported() = PluginManagementLoadResultUnsupported;

  const factory PluginManagementLoadResult.failure({required ApiError error}) = PluginManagementLoadResultFailure;
}

final class PluginManagementLoadResultSupported extends PluginManagementLoadResult {
  final PluginManagementResponse response;

  /// Non-null when this publication replays a retained snapshot after a
  /// refresh failure against the same bridge identity.
  final ApiError? refreshError;

  const PluginManagementLoadResultSupported({required this.response, required this.refreshError});
}

final class PluginManagementLoadResultUnsupported extends PluginManagementLoadResult {
  const PluginManagementLoadResultUnsupported();
}

final class PluginManagementLoadResultFailure extends PluginManagementLoadResult {
  final ApiError error;

  const PluginManagementLoadResultFailure({required this.error});
}

sealed class PluginManagementMutationResult {
  const PluginManagementMutationResult();

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

final class PluginManagementMutationResultSuccess extends PluginManagementMutationResult {
  final PluginManagementResponse response;

  const PluginManagementMutationResultSuccess({required this.response});
}

final class PluginManagementMutationResultNotFound extends PluginManagementMutationResult {
  const PluginManagementMutationResultNotFound();
}

final class PluginManagementMutationResultConflict extends PluginManagementMutationResult {
  final PluginLifecycleConflict conflict;

  const PluginManagementMutationResultConflict({required this.conflict});
}

final class PluginManagementMutationResultUncertain extends PluginManagementMutationResult {
  const PluginManagementMutationResultUncertain();
}

final class PluginManagementMutationResultFailure extends PluginManagementMutationResult {
  final ApiError error;

  const PluginManagementMutationResultFailure({required this.error});
}
