import "dart:async";

import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/session_abort_service.dart";
import "package:test/test.dart";

void main() {
  group("SessionAbortService", () {
    late _FakeSessionRepository sessionRepository;
    late SessionAbortService service;

    setUp(() {
      sessionRepository = _FakeSessionRepository();
      service = SessionAbortService(sessionRepository: sessionRepository);
    });

    tearDown(() => service.dispose());

    test("emits aborted session before awaiting repository abort", () async {
      final emittedSessionIds = <String>[];
      final abortStarted = Completer<void>();
      sessionRepository.onAbort = ({required String sessionId}) async {
        abortStarted.complete();
        await sessionRepository.abortCompleter.future;
      };

      final subscription = service.abortedSessions.listen(emittedSessionIds.add);
      addTearDown(subscription.cancel);

      unawaited(service.abortSession(sessionId: "session-1"));
      await abortStarted.future;

      expect(emittedSessionIds, equals(["session-1"]));
    });
  });
}

class _FakeSessionRepository implements SessionRepository {
  final Completer<void> abortCompleter = Completer<void>();
  Future<void> Function({required String sessionId})? onAbort;

  @override
  Future<void> abortSession({required String sessionId}) async {
    await onAbort?.call(sessionId: sessionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
