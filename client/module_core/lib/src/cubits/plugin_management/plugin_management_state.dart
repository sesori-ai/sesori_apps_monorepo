import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

part "plugin_management_state.freezed.dart";

enum PluginManagementActionStatus { idle, inProgress, failure }

enum PluginManagementForceAction { disable, restart }

@Freezed()
sealed class PluginManagementActionError with _$PluginManagementActionError {
  const factory PluginManagementActionError.invalidIdleTimeout() = PluginManagementInvalidIdleTimeout;

  const factory PluginManagementActionError.notFound() = PluginManagementActionNotFound;

  const factory PluginManagementActionError.conflict({required PluginLifecycleConflict conflict}) =
      PluginManagementActionConflict;

  const factory PluginManagementActionError.request({required ApiError error}) = PluginManagementActionRequestError;
}

@Freezed()
sealed class PluginManagementState with _$PluginManagementState {
  const factory PluginManagementState.loading() = PluginManagementLoading;

  const factory PluginManagementState.unsupported() = PluginManagementUnsupportedState;

  const factory PluginManagementState.failure({required ApiError error}) = PluginManagementFailure;

  const factory PluginManagementState.ready({
    required PluginManagementResponse response,
    required PluginManagementActionStatus actionStatus,
    required String? actingPluginId,
    required PluginManagementForceAction? pendingForceAction,
    required PluginManagementActionError? actionError,
  }) = PluginManagementReady;
}
