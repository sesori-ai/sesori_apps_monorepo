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

    test("emits aborted session only after repository abort succeeds", () async {
      final startedSessionIds = <String>[];
      final emittedSessionIds = <String>[];
      final abortStarted = Completer<void>();
      sessionRepository.onAbort = ({required String sessionId}) async {
        abortStarted.complete();
        await sessionRepository.abortCompleter.future;
      };

      final startedSubscription = service.abortStartedSessions.listen(startedSessionIds.add);
      final subscription = service.abortedSessions.listen(emittedSessionIds.add);
      addTearDown(startedSubscription.cancel);
      addTearDown(subscription.cancel);

      final abortFuture = service.abortSession(sessionId: "session-1");
      await abortStarted.future;

      expect(startedSessionIds, equals(["session-1"]));
      expect(emittedSessionIds, isEmpty);

      sessionRepository.abortCompleter.complete();
      await abortFuture;

      expect(emittedSessionIds, equals(["session-1"]));
    });

    test("does not emit aborted session when repository abort fails", () async {
      final startedSessionIds = <String>[];
      final emittedSessionIds = <String>[];
      final failedSessionIds = <String>[];
      sessionRepository.onAbort = ({required String sessionId}) async {
        throw StateError("abort failed for $sessionId");
      };

      final startedSubscription = service.abortStartedSessions.listen(startedSessionIds.add);
      final subscription = service.abortedSessions.listen(emittedSessionIds.add);
      final failedSubscription = service.abortFailedSessions.listen(failedSessionIds.add);
      addTearDown(startedSubscription.cancel);
      addTearDown(subscription.cancel);
      addTearDown(failedSubscription.cancel);

      await expectLater(
        service.abortSession(sessionId: "session-1"),
        throwsA(isA<StateError>()),
      );

      expect(startedSessionIds, equals(["session-1"]));
      expect(emittedSessionIds, isEmpty);
      expect(failedSessionIds, equals(["session-1"]));
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
