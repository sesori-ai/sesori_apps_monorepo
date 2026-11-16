import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";

import "models/session_sending.dart";

/// The sends this app started that have not ended, by source session id, so
/// the session list can show a source while it is being sent.
///
/// [SessionActionService] is the only writer: it starts an entry when a send
/// goes out and ends it with the send's outcome.
@lazySingleton
class SessionSendTracker() with Disposable {
  final BehaviorSubject<Map<String, SessionSending>> _sending = BehaviorSubject.seeded(const {});

  ValueStream<Map<String, SessionSending>> get sending => _sending.stream;

  Map<String, SessionSending> get currentSending => _sending.value;

  void start({required String sourceSessionId, required SessionSending sending}) {
    _sending.add(Map.unmodifiable({..._sending.value, sourceSessionId: sending}));
  }

  /// Ends [sending], unless a later send of the same source replaced it.
  void end({required String sourceSessionId, required SessionSending sending}) {
    if (!identical(_sending.value[sourceSessionId], sending)) return;
    _sending.add(Map.unmodifiable({..._sending.value}..remove(sourceSessionId)));
  }

  @override
  void onDispose() => _sending.close();
}
