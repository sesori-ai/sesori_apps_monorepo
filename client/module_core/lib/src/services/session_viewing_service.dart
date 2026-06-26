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
/// On background it declares "viewing nothing" but retains the intended session.
/// It deliberately does NOT auto-re-assert the view on reconnect or foreground:
/// declaring "viewed" marks the session seen on the bridge (clearing its bold
/// globally), so it must only happen once the screen is showing fresh content.
/// After a resume/reconnect the owning [SessionDetailCubit] runs a silent
/// refresh and re-calls [setViewingSession] when that refresh has rendered, so
/// activity that arrived while hidden/disconnected is seen before the bold is
/// cleared.
@lazySingleton
class SessionViewingService with Disposable {
  final SessionViewRepository _viewRepository;
  StreamSubscription<LifecycleState>? _lifecycleSubscription;

  String? _currentSessionId;
  bool _isPaused = false;

  /// Serializes outgoing view declarations so they are sent in submission
  /// order. Each relay send awaits encryption before hitting the socket, so
  /// without this an older `clear` could overtake a newer `set` (e.g. navigating
  /// directly from session A to B) and leave the bridge thinking nothing is
  /// viewed while the user actively watches B.
  Future<void> _sendTail = Future<void>.value();

  SessionViewingService({
    required SessionViewRepository viewRepository,
    required LifecycleSource lifecycleSource,
  }) : _viewRepository = viewRepository {
    _lifecycleSubscription = lifecycleSource.lifecycleStateStream.listen(_onLifecycleChanged);
  }

  /// Declares that the user is now viewing [sessionId].
  void setViewingSession(String sessionId) {
    _currentSessionId = sessionId;
    // While backgrounded/hidden, remember the intended session but don't tell
    // the bridge — otherwise a load that finishes after the app is no longer
    // visible would mark the session read before the user sees it. Resume
    // re-asserts `_currentSessionId`.
    if (_isPaused) return;
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
    _sendTail = _sendTail.then((_) => _viewRepository.sendSessionView(sessionId: sessionId));
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
        // No longer visible (backgrounded or minimized): stop viewing on the
        // bridge but keep the intended session. Resume does NOT re-assert here;
        // the detail cubit re-calls setViewingSession after its silent refresh
        // renders fresh content, so activity received while hidden is seen
        // before the bold clears.
        if (_currentSessionId != null) {
          _enqueueSend(null);
        }
      case LifecycleState.resumed:
        // Only flip the paused flag; the cubit drives the re-assert once the
        // post-resume refresh has rendered (see class doc).
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
