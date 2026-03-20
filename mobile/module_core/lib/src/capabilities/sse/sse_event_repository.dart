import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../server_connection/connection_service.dart";
import "../server_connection/models/sse_event.dart";

@lazySingleton
class SseEventRepository with Disposable {
  final ConnectionService _connectionService;
  late final StreamSubscription<SseEvent> _subscription;

  final BehaviorSubject<Map<String, int>> _projectActivity = BehaviorSubject.seeded(const {});

  SseEventRepository(ConnectionService connectionService) : _connectionService = connectionService {
    _subscription = _connectionService.events.listen(_handleEvent);
  }

  /// Map of worktree path -> active session count.
  ///
  /// Only includes projects with `activeSessions > 0`.
  /// Late subscribers immediately receive the latest cached value.
  ValueStream<Map<String, int>> get projectActivity => _projectActivity.stream;

  /// The latest project activity map, synchronously available.
  Map<String, int> get currentProjectActivity => _projectActivity.value;

  void _handleEvent(SseEvent event) {
    if (event.data case SesoriProjectsSummary(:final projects)) {
      final map = <String, int>{};
      for (final summary in projects) {
        if (summary.activeSessions > 0) {
          map[summary.worktree] = summary.activeSessions;
        }
      }
      _projectActivity.add(map);
    }
  }

  @override
  FutureOr<void> onDispose() {
    _subscription.cancel();
    _projectActivity.close();
  }
}
