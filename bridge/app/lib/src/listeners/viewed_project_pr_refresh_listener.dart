import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../services/pr_sync_service.dart";
import "../services/project_view_tracker.dart";
import "../services/pull_request_refresh_settings_service.dart";

/// Schedules pull request refreshes while at least one project is being viewed.
class ViewedProjectPrRefreshListener({
  required final ProjectViewTracker _tracker,
  required final PrSyncService _prSyncService,
  required final PullRequestRefreshSettingsService _settingsService,
}) {
  final CompositeSubscription _subscriptions = CompositeSubscription();
  Timer? _timer;
  Future<void>? _disposeFuture;
  final PendingOperations _activeRefreshes = PendingOperations();
  int _latestAdmission = 0;
  bool _disposed = false;
  bool _started = false;
  late Duration _refreshInterval;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _refreshInterval = Duration(seconds: _settingsService.currentSettings.intervalSeconds);

    _tracker.changes
        .listen(
          (change) => _handleChange(change: change),
          onError: (Object error, StackTrace stackTrace) {
            if (_disposed) return;
            Log.w(
              "Viewed-project change tracking failed unexpectedly",
              error,
              stackTrace,
            );
          },
        )
        .addTo(_subscriptions);
    _settingsService.changes
        .listen(
          (settings) => _handleIntervalChange(intervalSeconds: settings.intervalSeconds),
          onError: (Object error, StackTrace stackTrace) {
            if (_disposed) return;
            Log.w(
              "Pull request refresh settings changes failed unexpectedly",
              error,
              stackTrace,
            );
          },
        )
        .addTo(_subscriptions);
    final activeProjectIds = _tracker.activeProjectIds;
    if (activeProjectIds.isNotEmpty) {
      _admitRefresh(projectIds: activeProjectIds);
    }
  }

  void _handleIntervalChange({required int intervalSeconds}) {
    if (_disposed) return;
    _refreshInterval = Duration(seconds: intervalSeconds);
    if (_timer == null) return;
    _armTimer();
  }

  void _handleChange({required ProjectViewChange change}) {
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
    unawaited(
      _activeRefreshes.track(
        operation: _refresh(projectIds: projectIds, admission: admission),
      ),
    );
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
    } on Object catch (error, stackTrace) {
      if (!_disposed) {
        Log.w(
          "Viewed-project pull request refresh failed unexpectedly; retrying after the configured interval",
          error,
          stackTrace,
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
    await _subscriptions.cancel();
    await _activeRefreshes.drain();
  }
}
