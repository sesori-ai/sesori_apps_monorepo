import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";

part "project_list_state.freezed.dart";

@Freezed()
sealed class ProjectListState with _$ProjectListState {
  const factory ProjectListState.loading() = ProjectListLoading;

  const factory ProjectListState.loaded({
    required List<Project> projects,
    required Map<String, int> activityById,
    @Default(false) bool isRefreshing,
  }) = ProjectListLoaded;

  const factory ProjectListState.failed({required RemoteFailureReason reason}) = ProjectListFailed;

  /// The bridge (the user's computer) is not connected, so there are no
  /// projects to show yet. Drives the "Let's connect your computer"
  /// onboarding. Emitted when the connection is `ConnectionDisconnected` or
  /// `ConnectionBridgeOffline`; replaced once the bridge comes online.
  const factory ProjectListState.bridgeDisconnected() = ProjectListBridgeDisconnected;
}
