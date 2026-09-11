import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/repositories/models/session_abort_not_accepted_exception.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/session_abort_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockSessionRepository() extends Mock implements SessionRepository;

void main() {
  test("typed root refusal retains cause and prevents descendant fallback", () async {
    final repository = _MockSessionRepository();
    final service = SessionAbortService(repository: repository);
    const refusal = SessionAbortRefusal(
      kind: SessionAbortRefusalKind.notPerformed,
      reason: SessionAbortRefusalReason.residentWorkCompletionUnknown,
    );
    final cause = StateError("typed refusal");
    final failure = SessionAbortNotAcceptedException(refusal: refusal, innerError: cause);
    when(
      () => repository.abortSession(
        sessionId: "root",
        subAgents: SessionAbortSubAgentPolicy.stop,
      ),
    ).thenThrow(failure);

    await expectLater(
      service.abortSession(
        sessionId: "root",
        subAgents: SessionAbortSubAgentPolicy.stop,
        childStatuses: const {"child": SessionStatus.busy()},
      ),
      throwsA(same(failure)),
    );
    verifyNever(
      () => repository.abortSession(
        sessionId: "child",
        subAgents: SessionAbortSubAgentPolicy.stop,
      ),
    );
  });
}
