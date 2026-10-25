import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../capabilities/server_connection/target_bridge_change_tracker.dart";
import "project_list_service.dart";

/// The session list's project filter, for the app's run only (never persisted).
///
/// It clears itself when its project leaves the project list, and when the
/// connection moves to another computer, whose projects are different.
@lazySingleton
class SessionListFilterTracker({
  required ConnectionService connectionService,
  required ProjectListService projectListService,
}) {
  final BehaviorSubject<String?> _projectId = BehaviorSubject.seeded(null);
  final CompositeSubscription _subscriptions = CompositeSubscription();
  final TargetBridgeChangeTracker _targetChange = TargetBridgeChangeTracker(
    initialStatus: connectionService.currentStatus,
  );

  /// The project the list is filtered to, or null for every project.
  ValueStream<String?> get projectId => _projectId.stream;

  this {
    _subscriptions
      ..add(connectionService.status.listen(_onConnectionStatus))
      ..add(projectListService.listedProjects.listen(_onListedProjects));
  }

  /// Only `AllSessionsCubit.selectProject` calls this.
  void select({required String? projectId}) => _projectId.add(projectId);

  void _onConnectionStatus(ConnectionStatus status) {
    if (_targetChange.changed(status: status)) _clear();
  }

  void _onListedProjects(List<ProjectSummary> projects) {
    final projectId = _projectId.value;
    if (projectId != null && !projects.any((project) => project.id == projectId)) _clear();
  }

  void _clear() {
    if (_projectId.value != null) _projectId.add(null);
  }

  @disposeMethod
  Future<void> dispose() async {
    await _subscriptions.dispose();
    await _projectId.close();
  }
}
