import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

part "plugin_management_result.freezed.dart";

@Freezed()
sealed class PluginManagementLoadResult with _$PluginManagementLoadResult {
  const factory PluginManagementLoadResult.supported({required PluginManagementResponse response}) =
      PluginManagementSupported;

  const factory PluginManagementLoadResult.unsupported() = PluginManagementUnsupported;

  const factory PluginManagementLoadResult.failure({required ApiError error}) = PluginManagementLoadFailure;
}

@Freezed()
sealed class PluginManagementMutationResult with _$PluginManagementMutationResult {
  const factory PluginManagementMutationResult.success({required PluginManagementResponse response}) =
      PluginManagementMutationSuccess;

  const factory PluginManagementMutationResult.notFound() = PluginManagementMutationNotFound;

  const factory PluginManagementMutationResult.conflict({required PluginLifecycleConflict conflict}) =
      PluginManagementMutationConflict;

  const factory PluginManagementMutationResult.failure({required ApiError error}) = PluginManagementMutationFailure;
}
