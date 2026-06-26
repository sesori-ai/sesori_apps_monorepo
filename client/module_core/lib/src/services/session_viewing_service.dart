import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../platform/lifecycle_source.dart";
import "../repositories/session_view_repository.dart";

/// Layer-3 owner of the "which session am I viewing" state. Cubits call this
/// (never `ConnectionService` transport directly). It keeps the current viewed
/// session id, declares it to the bridge via [SessionViewRepository], and
/// re-asserts it after a reconnect or an app foreground transition. On
/// background it declares "viewing nothing" but retains the intended session so
/// resume can re-assert it.
@lazySingleton
class SessionViewingService with Disposable {
  final SessionViewRepository _viewRepository;
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  StreamSubscription<LifecycleState>? _lifecycleSubscription;

  String? _currentSessionId;
  bool _wasConnected = false;

  /// Serializes outgoing view declarations so they are sent in submission
  /// order. Each relay send awaits encryption before hitting the socket, so
  /// without this an older `clear` could overtake a newer `set` (e.g. navigating
  /// directly from session A to B) and leave the bridge thinking nothing is
  /// viewed while the user actively watches B.
  Future<void> _sendTail = Future<void>.value();

  SessionViewingService({
    required SessionViewRepository viewRepository,
    required ConnectionService connectionService,
    required LifecycleSource lifecycleSource,
  }) : _viewRepository = viewRepository {
    _statusSubscription = connectionService.status.listen(_onStatusChanged);
    _lifecycleSubscription = lifecycleSource.lifecycleStateStream.listen(_onLifecycleChanged);
  }

  /// Declares that the user is now viewing [sessionId].
  void setViewingSession(String sessionId) {
    _currentSessionId = sessionId;
    _enqueueSend(sessionId);
  }

  /// Declares that the user stopped viewing [sessionId]. Guarded so a late
  /// "clear" from a screen that was already replaced by another session does
  /// not wipe the newer session's view (split-view / navigation race).
  void clearViewingSession(String sessionId) {
    if (_currentSessionId != sessionId) return;
    _currentSessionId = null;
    _enqueueSend(null);
  }

  /// Chains [sessionId] onto the serialized send tail so declarations are
  /// transmitted in order. The repository send already swallows transport
  /// errors, so the tail never breaks.
  void _enqueueSend(String? sessionId) {
    _sendTail = _sendTail.then((_) => _viewRepository.sendSessionView(sessionId));
    unawaited(_sendTail);
  }

  /// Awaited by tests to let the serialized send tail drain before verifying.
  @visibleForTesting
  Future<void> get sendTail => _sendTail;

  void _onStatusChanged(ConnectionStatus status) {
    final isConnected = status is ConnectionConnected;
    // Re-assert the current view each time we (re)enter the connected state.
    if (isConnected && !_wasConnected && _currentSessionId != null) {
      _enqueueSend(_currentSessionId);
    }
    _wasConnected = isConnected;
  }

  void _onLifecycleChanged(LifecycleState state) {
    switch (state) {
      case LifecycleState.paused:
        // Backgrounded: stop viewing on the bridge but keep the intended
        // session so resume can re-assert it.
        if (_currentSessionId != null) {
          _enqueueSend(null);
        }
      case LifecycleState.resumed:
        if (_currentSessionId != null) {
          _enqueueSend(_currentSessionId);
        }
      case LifecycleState.inactive:
      case LifecycleState.hidden:
      case LifecycleState.detached:
        break;
    }
  }

  @override
  FutureOr<void> onDispose() {
    _statusSubscription?.cancel();
    _lifecycleSubscription?.cancel();
  }
}
