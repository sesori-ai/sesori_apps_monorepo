import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../bridge/services/pr_sync_service.dart";
import "../services/project_view_tracker.dart";

/// Schedules pull request refreshes while at least one project is being viewed.
class ViewedProjectPrRefreshListener {
  final ProjectViewTracker _tracker;
  final PrSyncService _prSyncService;
  final Duration _refreshInterval;

  StreamSubscription<ProjectViewChange>? _subscription;
  Timer? _timer;
  Future<void>? _disposeFuture;
  final Set<Future<void>> _activeRefreshes = <Future<void>>{};
  int _latestAdmission = 0;
  bool _disposed = false;

  ViewedProjectPrRefreshListener({
    required ProjectViewTracker tracker,
    required PrSyncService prSyncService,
    required Duration refreshInterval,
  }) : _tracker = tracker,
       _prSyncService = prSyncService,
       _refreshInterval = refreshInterval;

  void start() {
    if (_subscription != null || _disposed) return;

    _subscription = _tracker.changes.listen(
      _handleChange,
      onError: (Object error, StackTrace _) {
        if (_disposed) return;
        Log.w(
          "Viewed-project change tracking failed unexpectedly",
          _PrivacySafeViewedProjectRefreshException(cause: error),
        );
      },
    );
    final activeProjectIds = _tracker.activeProjectIds;
    if (activeProjectIds.isNotEmpty) {
      _admitRefresh(projectIds: activeProjectIds);
    }
  }

  void _handleChange(ProjectViewChange change) {
    if (_disposed) return;
    if (change.activeProjectIds.isEmpty) {
      _cancelSchedule();
      return;
    }
    if (change.newlyAddedProjectIds.isEmpty) return;

    _timer?.cancel();
    _timer = null;
    _admitRefresh(projectIds: change.newlyAddedProjectIds);
  }

  void _admitRefresh({required Set<String> projectIds}) {
    if (_disposed || projectIds.isEmpty) return;

    final admission = ++_latestAdmission;
    late final Future<void> refresh;
    refresh = _refresh(
      projectIds: projectIds,
      admission: admission,
    ).whenComplete(() => _activeRefreshes.remove(refresh));
    _activeRefreshes.add(refresh);
    unawaited(refresh);
  }

  Future<void> _refresh({
    required Set<String> projectIds,
    required int admission,
  }) async {
    try {
      await _prSyncService.triggerRefresh(
        projectIds: projectIds,
        refreshPolicy: PrRefreshPolicy.viewedProject,
      );
    } on Object catch (error) {
      if (!_disposed) {
        Log.w(
          "Viewed-project pull request refresh failed unexpectedly; retrying after the configured interval",
          _PrivacySafeViewedProjectRefreshException(cause: error),
        );
      }
    }

    if (_disposed || admission != _latestAdmission || _tracker.activeProjectIds.isEmpty) return;
    _armTimer();
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = Timer(_refreshInterval, () {
      _timer = null;
      if (_disposed) return;

      final activeProjectIds = _tracker.activeProjectIds;
      if (activeProjectIds.isEmpty) return;
      _admitRefresh(projectIds: activeProjectIds);
    });
  }

  void _cancelSchedule() {
    _latestAdmission++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _cancelSchedule();
    await _subscription?.cancel();
    _subscription = null;
    await Future.wait(List<Future<void>>.of(_activeRefreshes));
  }
}

final class _PrivacySafeViewedProjectRefreshException implements Exception {
  final Object cause;

  const _PrivacySafeViewedProjectRefreshException({required this.cause});

  @override
  String toString() => "ViewedProjectRefreshException";
}
