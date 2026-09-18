import "dart:async";

import "package:injectable/injectable.dart";

import "../logging/logging.dart";

final class const ProjectInventoryRefreshResult({
  required final bool succeeded,
  required final List<String> projectIds,
});

final class ProjectInventoryRefreshRequest() {
  final Completer<ProjectInventoryRefreshResult> _completion = Completer<ProjectInventoryRefreshResult>();

  Future<ProjectInventoryRefreshResult> get result => _completion.future;

  void complete({required ProjectInventoryRefreshResult result}) {
    if (!_completion.isCompleted) _completion.complete(result);
  }
}

final class SessionInventoryRefreshRequest({required Iterable<String> projectIds}) {
  final Completer<bool> _completion = Completer<bool>();
  final List<String> projectIds = List.unmodifiable(projectIds.toSet());

  Future<bool> get result => _completion.future;

  void complete({required bool succeeded}) {
    if (!_completion.isCompleted) _completion.complete(succeeded);
  }
}

/// Lower-layer owner of explicit inventory refresh requests and outcomes.
///
/// Inventory Cubits consume their independent request streams and project the
/// existing refresh paths into presentation state. Callers depend only on this
/// service, so no workflow needs a Cubit dependency or a second data cache.
@lazySingleton
class InventoryRefreshService() {
  final StreamController<ProjectInventoryRefreshRequest> _projectRequests =
      StreamController<ProjectInventoryRefreshRequest>.broadcast(sync: true);
  final StreamController<SessionInventoryRefreshRequest> _sessionRequests =
      StreamController<SessionInventoryRefreshRequest>.broadcast(sync: true);
  bool _disposed = false;

  Stream<ProjectInventoryRefreshRequest> get projectRequests => _projectRequests.stream;
  Stream<SessionInventoryRefreshRequest> get sessionRequests => _sessionRequests.stream;

  Future<ProjectInventoryRefreshResult> refreshProjectInventory() {
    if (_disposed || !_projectRequests.hasListener) {
      logw("Cannot refresh project inventory without an active owner");
      return Future.value(const ProjectInventoryRefreshResult(succeeded: false, projectIds: []));
    }
    final request = ProjectInventoryRefreshRequest();
    _projectRequests.add(request);
    return request.result;
  }

  Future<bool> refreshSessionInventories({required Iterable<String> projectIds}) {
    final request = SessionInventoryRefreshRequest(projectIds: projectIds);
    if (request.projectIds.isEmpty) return Future.value(true);
    if (_disposed || !_sessionRequests.hasListener) {
      logw("Cannot refresh session inventories without an active owner");
      return Future.value(false);
    }
    _sessionRequests.add(request);
    return request.result;
  }

  @disposeMethod
  Future<void> dispose() async {
    _disposed = true;
    await Future.wait([_projectRequests.close(), _sessionRequests.close()]);
  }
}
