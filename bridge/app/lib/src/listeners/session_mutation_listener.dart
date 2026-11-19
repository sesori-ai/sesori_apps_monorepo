import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show BridgeSseMessageRemoved, BridgeSseProjectUpdated, BridgeSseSessionDeleted, BridgeSseSessionUpdated;

import "../services/session_event_dispatcher.dart";
import "../services/session_mutation_dispatcher.dart";
import "../services/session_view_service.dart";

/// Fans each bridge-persisted session mutation out to every client as the
/// events a backend's own change would produce.
class SessionMutationListener({
  required final Stream<LocalSessionMutation> _source,
  required final SessionViewService _views,
  required final SessionEventDispatcher _dispatcher,
}) {
  StreamSubscription<LocalSessionEvent>? _subscription;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source
        .asyncMap((mutation) => _map(mutation: mutation))
        .listen(
          (event) => unawaited(_dispatcher.dispatchLocalEvent(source: event)),
          onError: _dispatcher.addSourceError,
        );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
  }

  Future<LocalSessionEvent> _map({required LocalSessionMutation mutation}) async {
    final session = switch (mutation) {
      SessionDeleted() || SessionContinuationUpdated() || SessionMessagesRewound() => mutation.session,
      SessionTitleUpdated() ||
      SessionApprovalOverrideUpdated() ||
      SessionPinnedUpdated() ||
      SessionInterruptionUpdated() ||
      SessionArchived() => await _views.enrich(session: mutation.session),
    };
    return (
      pluginId: session.pluginId,
      events: switch (mutation) {
        SessionTitleUpdated() => [BridgeSseSessionUpdated(info: session.toJson(), titleChanged: true)],
        SessionContinuationUpdated() ||
        SessionApprovalOverrideUpdated() ||
        SessionPinnedUpdated() ||
        SessionInterruptionUpdated() => [
          BridgeSseSessionUpdated(info: session.toJson(), titleChanged: false),
        ],
        SessionDeleted() => [BridgeSseSessionDeleted(info: session.toJson())],
        // Open lists and session pages learn the archive from the updated
        // session. A backend may keep reporting an archived session running
        // or waiting, so the summary, which drops archived sessions, is
        // rebuilt at once too.
        SessionArchived() => [
          BridgeSseSessionUpdated(info: session.toJson(), titleChanged: false),
          const BridgeSseProjectUpdated(),
        ],
        // Each removal is stored and fanned out like a backend's own.
        SessionMessagesRewound(:final removedMessageIds) => [
          for (final messageId in removedMessageIds)
            BridgeSseMessageRemoved(sessionID: session.id, messageID: messageId),
        ],
      },
    );
  }
}
