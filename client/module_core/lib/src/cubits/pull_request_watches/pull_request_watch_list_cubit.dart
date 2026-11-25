import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/server_connection/target_bridge_change_tracker.dart";
import "../../logging/logging.dart";
import "../../repositories/models/pull_request_watch_list_result.dart";
import "../../repositories/pull_request_watch_repository.dart";
import "../../repositories/session_repository.dart";
import "../scheduled_tasks/scheduled_task_refresh.dart";
import "pull_request_watch_list_state.dart";

/// The current computer's watched pull requests, for the home button, the
/// list and the desktop row. It reloads whenever the bridge says they changed,
/// the connection comes back, or the data may be stale.
class PullRequestWatchListCubit({
  required final PullRequestWatchRepository _repository,
  required final SessionRepository _sessionRepository,
  required final ConnectionService _connectionService,
}) extends Cubit<PullRequestWatchListState> {
  late final StreamSubscription<void> _signals;
  late final StreamSubscription<ConnectionStatus> _statuses;
  late final TargetBridgeChangeTracker _targetChange = TargetBridgeChangeTracker(
    initialStatus: _connectionService.currentStatus,
  );

  /// The watches as the bridge last listed them.
  List<PullRequestWatchListItem> _watches = const [];

  /// Each load's number; a computer switch drops the answer of a load in
  /// flight.
  int _loads = 0;

  // Serializes loads, and retries a failed one a few times: the bridge only
  // announces changes, so a missed load could otherwise stay stale.
  late final ScheduledTaskRefreshDispatcher _queue = ScheduledTaskRefreshDispatcher(refresh: _load);

  /// Auto-merge positions sent but not yet answered. They override
  /// [_watches], so a reload that lands meanwhile does not flick the mark
  /// back. Each tap's [request] number tells its answer whether a newer tap
  /// followed.
  final Map<PullRequestWatchKey, ({bool enabled, int request})> _pendingAutoMerge = {};
  int _autoMergeRequests = 0;
  final Set<PullRequestWatchKey> _stopping = {};

  this : super(const PullRequestWatchListLoading()) {
    _statuses = _connectionService.status.listen(_onStatus);
    _signals = MergeStream<void>([
      _connectionService.events.where((event) => event.data is SesoriPullRequestWatchesChanged),
      _connectionService.status
          .map((status) => status is ConnectionConnected)
          .distinct()
          // The first value is the current status, not a reconnect.
          .skip(1)
          .where((isConnected) => isConnected),
      _connectionService.dataMayBeStale,
    ]).listen((_) => unawaited(refresh()));
    unawaited(refresh());
  }

  /// Reloads the list once any load in flight is done.
  Future<void> refresh() => _queue.request();

  /// Loads the list; false when nothing was applied, so the load is retried.
  Future<bool> _load() async {
    final load = ++_loads;
    final PullRequestWatchListResult result;
    try {
      result = await _repository.listWatches();
    } on Object catch (error, stackTrace) {
      logw("Failed to load watched pull requests", error, stackTrace);
      if (!isClosed && load == _loads && state is PullRequestWatchListLoading) {
        emit(const PullRequestWatchListFailed());
      }
      return false;
    }
    // After a computer switch, the reconnect that follows loads again.
    if (isClosed || load != _loads) return true;
    switch (result) {
      case PullRequestWatchListSuccess(:final watches):
        _watches = watches;
        _emitLoaded();
        return true;
      case PullRequestWatchListBridgeOutdated():
        emit(const PullRequestWatchListUnsupported());
        return true;
      case PullRequestWatchListFailure(:final error):
        logw("Failed to load watched pull requests", error);
        // Watches already shown stay until a retry or the next signal.
        if (state is PullRequestWatchListLoading) emit(const PullRequestWatchListFailed());
        return false;
    }
  }

  /// Shows the loading state again and reloads, after a failed load.
  Future<void> retry() {
    emit(const PullRequestWatchListLoading());
    return refresh();
  }

  /// Turns the bridge's auto-merge for [item] on or off. The mark moves at
  /// once; the bridge's answer decides where it ends, and false means it went
  /// back.
  Future<bool> setAutoMerge({required PullRequestWatchListItem item, required bool enabled}) async {
    final key = item.key;
    final pending = (enabled: enabled, request: ++_autoMergeRequests);
    _pendingAutoMerge[key] = pending;
    _emitLoaded();
    final response = await _sessionRepository.setPullRequestWatchAutoMerge(
      sessionId: key.sessionId,
      repository: key.repository,
      number: key.number,
      enabled: enabled,
    );
    if (isClosed) return false;
    if (response case ErrorResponse(:final error)) {
      logw("Failed to turn auto-merge ${enabled ? "on" : "off"} for ${key.repository}#${key.number}", error);
    }
    // A newer tap owns the mark until its own answer settles it.
    if (_pendingAutoMerge[key] != pending) return response is SuccessResponse;
    _pendingAutoMerge.remove(key);
    switch (response) {
      case SuccessResponse(:final data):
        final updated = data.pullRequestWatches.where(
          (watch) => watch.repository == key.repository && watch.number == key.number,
        );
        _watches = [
          for (final listed in _watches)
            if (listed.key == key && updated.isNotEmpty) listed.copyWith(watch: updated.first) else listed,
        ];
        _emitLoaded();
        return true;
      case ErrorResponse():
        _emitLoaded();
        return false;
    }
  }

  /// Stops the session's watch of [item]'s pull request. The row shows that
  /// it is stopping and leaves once the bridge agrees; false means it stays.
  Future<bool> stop({required PullRequestWatchListItem item}) async {
    final key = item.key;
    if (!_stopping.add(key)) return true;
    _emitLoaded();
    final response = await _sessionRepository.stopPullRequestWatch(
      sessionId: key.sessionId,
      repository: key.repository,
      number: key.number,
    );
    if (isClosed) return false;
    _stopping.remove(key);
    switch (response) {
      case SuccessResponse():
        _watches = [
          for (final listed in _watches)
            if (listed.key != key) listed,
        ];
        _emitLoaded();
        return true;
      case ErrorResponse(:final error):
        logw("Failed to stop watching ${key.repository}#${key.number} for session ${key.sessionId}", error);
        _emitLoaded();
        return false;
    }
  }

  /// Another computer's watches are not this one's: forget them, and let
  /// the reconnect that follows load the new computer's.
  void _onStatus(ConnectionStatus status) {
    if (isClosed || !_targetChange.changed(status: status)) return;
    _loads++;
    _watches = const [];
    _pendingAutoMerge.clear();
    _stopping.clear();
    emit(const PullRequestWatchListLoading());
  }

  void _emitLoaded() {
    if (isClosed) return;
    emit(
      PullRequestWatchListLoaded(
        watches: [
          for (final item in _watches)
            switch (_pendingAutoMerge[item.key]) {
              (:final enabled, request: _) => item.copyWith(watch: item.watch.copyWith(autoMerge: enabled)),
              null => item,
            },
        ],
        stopping: Set.unmodifiable(_stopping),
      ),
    );
  }

  @override
  Future<void> close() async {
    _queue.dispose();
    await _signals.cancel();
    await _statuses.cancel();
    return await super.close();
  }
}
