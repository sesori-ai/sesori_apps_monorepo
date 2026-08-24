import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "../../services/models/catalog_rescan_state.dart";

part "project_list_state.freezed.dart";

@Freezed()
sealed class ProjectListState with _$ProjectListState {
  const factory loading() = ProjectListLoading;

  const factory loaded({
    required List<ProjectSummary> projects,
    required Map<String, int> activityById,

    /// Map of project ID -> whether it has unseen changes (bold title). Merges
    /// the REST-seeded `Project.hasUnseenChanges` with live
    /// `SesoriSessionUnseenChanged` updates, the latter taking precedence.
    @Default({}) Map<String, bool> unseenByProjectId,
    @Default(false) bool isRefreshing,

    /// The catalog scan shown above the list, if any is worth showing.
    ///
    /// Carried here beside [isRefreshing] because it is the same kind of thing:
    /// transient operation status the list renders over its content. The scan
    /// itself is owned by `CatalogRescanService`; this is only the projection
    /// the screen watches.
    @Default(CatalogRescanState.idle()) CatalogRescanState catalogScan,
  }) = ProjectListLoaded;

  const factory failed({required RemoteFailureReason reason}) = ProjectListFailed;

  /// The bridge (the user's computer) is not connected, so there are no
  /// projects to show yet. Emitted when the connection is
  /// `ConnectionDisconnected`, or when it is `ConnectionBridgeOffline` while
  /// nothing is loaded — a non-empty [ProjectListLoaded] list is kept on
  /// screen instead, with the top-nav connection banner owning the offline
  /// messaging. Replaced once the bridge comes online.
  ///
  /// [hasRegisteredBridges] tells which recovery flow applies (from the
  /// account's registered bridges on the auth server):
  /// * `false` — the user never set up a bridge → "Set up Sesori Bridge"
  ///   onboarding.
  /// * `true` — a bridge is registered but not running → "turn on your
  ///   bridge" view.
  ///
  /// Which machine that bridge is — the name the recovery view and the top
  /// navigation show — is not part of this state: `BridgeIdentityCubit` owns it,
  /// because it resolves per connection rather than per project-list state.
  const factory bridgeDisconnected({
    required bool hasRegisteredBridges,
  }) = ProjectListBridgeDisconnected;
}
