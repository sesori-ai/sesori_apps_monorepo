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

    /// Map of project ID -> whether it has unseen changes (bold title). Merges
    /// the REST-seeded `Project.hasUnseenChanges` with live
    /// `SesoriSessionUnseenChanged` updates, the latter taking precedence.
    @Default({}) Map<String, bool> unseenByProjectId,
    @Default(false) bool isRefreshing,
  }) = ProjectListLoaded;

  const factory ProjectListState.failed({required RemoteFailureReason reason}) = ProjectListFailed;

  /// The bridge (the user's computer) is not connected, so there are no
  /// projects to show yet. Emitted when the connection is
  /// `ConnectionDisconnected` or `ConnectionBridgeOffline`; replaced once the
  /// bridge comes online.
  ///
  /// [hasRegisteredBridges] tells which recovery flow applies (from the
  /// account's registered bridges on the auth server):
  /// * `false` — the user never set up a bridge → "Set up Sesori Bridge"
  ///   onboarding.
  /// * `true` — a bridge is registered but not running → "turn on your
  ///   bridge" view.
  const factory ProjectListState.bridgeDisconnected({
    required bool hasRegisteredBridges,
  }) = ProjectListBridgeDisconnected;
}
