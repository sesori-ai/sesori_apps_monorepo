import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "../platform/lifecycle_source.dart";
import "../repositories/session_view_repository.dart";

/// Layer-3 owner of the "which session am I viewing" state. Cubits call this
/// (never `ConnectionService` transport directly). It keeps the current viewed
/// session id and declares it to the bridge via [SessionViewRepository].
///
/// On background it declares "viewing nothing" but retains the intended
/// session. It deliberately does NOT auto-re-assert on resume or reconnect:
/// declaring "viewed" marks the session seen on the bridge (clearing its bold
/// globally), so the owning `SessionDetailCubit` re-asserts only after its
/// post-resume/reconnect refresh has rendered fresh content.
@lazySingleton
class SessionViewingService with Disposable {
  final SessionViewRepository _viewRepository;
  StreamSubscription<LifecycleState>? _lifecycleSubscription;

  String? _currentSessionId;
  bool _isPaused = false;

  /// Serializes outgoing declarations so they reach the bridge in order (each
  /// relay send awaits encryption, so unqueued sends could overtake each
  /// other). Every queued send transmits the CURRENT state at execution time —
  /// never a value captured at enqueue time — so a send that executes after a
  /// navigation or background transition automatically reflects it; there is
  /// no stale-capture race to guard. Duplicate sends collapse on the bridge
  /// (setViewing is idempotent). The repository send swallows transport
  /// errors, so the tail never breaks.
  Future<void> _sendTail = Future<void>.value();

  SessionViewingService({
    required SessionViewRepository viewRepository,
    required LifecycleSource lifecycleSource,
  }) : _viewRepository = viewRepository {
    _lifecycleSubscription = lifecycleSource.lifecycleStateStream.listen(_onLifecycleChanged);
  }

  /// Declares that the user is now viewing [sessionId]. While backgrounded the
  /// intended session is remembered but "nothing" is declared until the detail
  /// cubit re-asserts after its post-resume refresh.
  void setViewingSession(String sessionId) {
    _currentSessionId = sessionId;
    _enqueueSend();
  }

  /// Declares that the user stopped viewing [sessionId]. Guarded so a late
  /// "clear" from a screen that was already replaced by another session does
  /// not wipe the newer session's view (navigation race).
  void clearViewingSession(String sessionId) {
    if (_currentSessionId != sessionId) return;
    _currentSessionId = null;
    _enqueueSend();
  }

  void _enqueueSend() {
    _sendTail = _sendTail.then(
      (_) => _viewRepository.sendSessionView(sessionId: _isPaused ? null : _currentSessionId),
    );
    unawaited(_sendTail);
  }

  /// Awaited by tests to let the serialized send tail drain before verifying.
  @visibleForTesting
  Future<void> get sendTail => _sendTail;

  void _onLifecycleChanged(LifecycleState state) {
    switch (state) {
      case LifecycleState.paused:
      case LifecycleState.hidden:
        // Mobile fires `hidden` then `paused` back-to-back; only act on the
        // first transition into the not-visible state to avoid a duplicate
        // clear send.
        if (_isPaused) return;
        _isPaused = true;
        if (_currentSessionId != null) _enqueueSend();
      case LifecycleState.resumed:
        // Only flip the flag; the detail cubit re-asserts after its refresh.
        _isPaused = false;
      case LifecycleState.inactive:
      case LifecycleState.detached:
        break;
    }
  }

  @override
  FutureOr<void> onDispose() {
    _lifecycleSubscription?.cancel();
  }
}
