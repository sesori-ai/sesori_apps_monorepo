import "dart:async";

import "package:sesori_bridge/src/repositories/models/session_abort_result.dart";
import "package:sesori_bridge/src/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/session_abort_service.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("SessionAbortService", () {
    late _FakeSessionRepository sessionRepository;
    late SessionAbortService service;
    late SessionOperationDispatcher dispatcher;

    setUp(() {
      sessionRepository = _FakeSessionRepository();
      dispatcher = SessionOperationDispatcher(sessionRepository: sessionRepository);
      service = SessionAbortService(
        sessionRepository: sessionRepository,
        dispatcher: dispatcher,
      );
    });

    tearDown(() async {
      await dispatcher.dispose();
      await service.dispose();
    });

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

      final abortFuture = service.abortSession(sessionId: "session-1", subAgents: SessionAbortSubAgentPolicy.stop);
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
        service.abortSession(sessionId: "session-1", subAgents: SessionAbortSubAgentPolicy.stop),
        throwsA(isA<StateError>()),
      );

      expect(startedSessionIds, equals(["session-1"]));
      expect(emittedSessionIds, isEmpty);
      expect(failedSessionIds, equals(["session-1"]));
    });

    test("emits abort failure when family resolution fails before execution", () async {
      final startedSessionIds = <String>[];
      final failedSessionIds = <String>[];
      sessionRepository.resolutionError = StateError("family unavailable");
      final startedSubscription = service.abortStartedSessions.listen(startedSessionIds.add);
      final failedSubscription = service.abortFailedSessions.listen(failedSessionIds.add);
      addTearDown(startedSubscription.cancel);
      addTearDown(failedSubscription.cancel);

      await expectLater(
        service.abortSession(sessionId: "missing", subAgents: SessionAbortSubAgentPolicy.stop),
        throwsStateError,
      );

      expect(startedSessionIds, ["missing"]);
      expect(failedSessionIds, ["missing"]);
    });
  });
}

class _FakeSessionRepository() implements SessionRepository {
  final Completer<void> abortCompleter = Completer<void>();
  Future<void> Function({required String sessionId})? onAbort;
  Object? resolutionError;

  @override
  Future<SessionAbortResult> abortSession({
    required String sessionId,
    required SessionAbortSubAgentPolicy subAgents,
  }) async {
    await onAbort?.call(sessionId: sessionId);
    return const SessionAborted(workKept: false);
  }

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    if (resolutionError case final error?) throw error;
    return (rootSessionId: sessionId, pluginId: "fake");
  }

  @override
  Future<void> ensurePluginRoutable({required String pluginId, required SessionOperation operation}) async {}

  @override
  Future<Session?> getCatalogSession({required String sessionId}) async => null;

  @override
  Future<SessionStatusResponse> getSessionStatuses() async => const SessionStatusResponse(statuses: {});

  @override
  Future<StoredSession> requireRoutableStoredSession({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    throw StateError("No stored session configured for $sessionId");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
