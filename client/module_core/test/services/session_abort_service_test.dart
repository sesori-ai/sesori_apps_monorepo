import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/repositories/models/session_abort_result.dart";
import "package:sesori_dart_core/src/services/session_abort_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("SessionAbortService", () {
    late MockSessionRepository repository;
    late SessionAbortService service;

    setUp(() {
      repository = MockSessionRepository();
      service = SessionAbortService(repository: repository);
    });

    test("exact remaining descendants do not depend on loaded screen state", () async {
      when(
        () => repository.abortSession(
          sessionId: "root",
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const SessionAbortResult(
            coverage: SessionAbortCoveragePartial(
              unhandledSessionIds: ["nested-child"],
            ),
          ),
        ),
      );
      when(
        () => repository.abortSession(
          sessionId: "nested-child",
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const SessionAbortResult(coverage: SessionAbortCoverageHandled()),
        ),
      );
      var legacyStateRead = false;

      await service.abort(
        sessionId: "root",
        subAgents: SessionAbortSubAgentPolicy.stop,
        readLegacyChildStatuses: () {
          legacyStateRead = true;
          return const {};
        },
      );

      expect(legacyStateRead, isFalse);
      verify(
        () => repository.abortSession(
          sessionId: "nested-child",
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      ).called(1);
    });

    test("legacy fallback stops only busy unhandled visible children", () async {
      when(
        () => repository.abortSession(
          sessionId: "root",
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const SessionAbortResult(
            coverage: SessionAbortCoverageLegacy(
              handledSessionIds: ["covered-child"],
            ),
          ),
        ),
      );
      when(
        () => repository.abortSession(
          sessionId: "busy-child",
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const SessionAbortResult(coverage: SessionAbortCoverageHandled()),
        ),
      );

      await service.abort(
        sessionId: "root",
        subAgents: SessionAbortSubAgentPolicy.stop,
        readLegacyChildStatuses: () => const {
          "covered-child": SessionStatus.busy(),
          "busy-child": SessionStatus.retry(attempt: 1, message: "Retrying", next: 1),
          "idle-child": SessionStatus.idle(),
        },
      );

      verify(
        () => repository.abortSession(
          sessionId: "busy-child",
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      ).called(1);
      verifyNever(
        () => repository.abortSession(
          sessionId: "covered-child",
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      );
      verifyNever(
        () => repository.abortSession(
          sessionId: "idle-child",
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      );
    });
  });
}
