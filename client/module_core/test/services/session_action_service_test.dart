import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/repositories/models/send_to_session_result.dart";
import "package:sesori_dart_core/src/repositories/models/session_cleanup_rejection.dart" as domain;
import "package:sesori_dart_core/src/services/models/session_cleanup_outcome.dart";
import "package:sesori_dart_core/src/services/models/session_delete_result.dart";
import "package:sesori_dart_core/src/services/selected_computer_service.dart";
import "package:sesori_dart_core/src/services/session_action_service.dart";
import "package:sesori_dart_core/src/services/session_cleanup_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

class _MockSelectedComputerService() extends Mock implements SelectedComputerService;

void main() {
  setUpAll(registerAllFallbackValues);

  const projectId = "project-1";
  late MockSessionRepository sessionRepository;
  late FakeSessionUnseenTracker unseen;
  late MockFailureReporter failureReporter;
  late SessionActionService actions;
  late _MockSelectedComputerService selectedComputer;
  late MockProductAnalyticsService analytics;

  setUp(() {
    analytics = stubbedProductAnalyticsService();
    selectedComputer = _MockSelectedComputerService();
    when(() => selectedComputer.targetBridgeId()).thenAnswer((_) async => "computer-a");
    sessionRepository = MockSessionRepository();
    unseen = FakeSessionUnseenTracker();
    failureReporter = MockFailureReporter();
    when(
      () => failureReporter.recordFailure(
        error: any(named: "error"),
        stackTrace: any(named: "stackTrace"),
        uniqueIdentifier: any(named: "uniqueIdentifier"),
        fatal: any(named: "fatal"),
        reason: any(named: "reason"),
        information: any(named: "information"),
      ),
    ).thenAnswer((_) async {});
    actions = SessionActionService(
      sessionRepository: sessionRepository,
      sessionCleanupService: SessionCleanupService(repository: sessionRepository),
      sessionUnseenTracker: unseen,
      failureReporter: failureReporter,
      selectedComputerService: selectedComputer,
      productAnalyticsService: analytics,
    );
  });

  tearDown(() => unseen.onDispose());

  group("delete", () {
    void stubDelete(Future<ApiResponse<void>> Function() answer) => when(
      () => sessionRepository.deleteSession(
        sessionId: "s1",
        deleteWorktree: any(named: "deleteWorktree"),
        deleteSessionFolder: any(named: "deleteSessionFolder"),
        force: any(named: "force"),
      ),
    ).thenAnswer((_) => answer());

    Future<SessionDeleteResult> delete() =>
        actions.deleteSession(sessionId: "s1", deleteWorktree: true, deleteSessionFolder: false, force: false);

    test("returns the outcome", () async {
      stubDelete(() async => ApiResponse<void>.success(null));

      expect(
        await delete(),
        isA<SessionDeleted>().having((r) => r.outcome, "outcome", SessionCleanupOutcome.completed),
      );
    });

    test("returns a cleanup rejection for the force dialog", () async {
      const issue = CleanupIssue.branchMismatch(expected: "feat/session-1", actual: "main");
      const rejection = SessionCleanupRejection(issues: [issue]);
      stubDelete(
        () => throw domain.SessionCleanupRejectedException(
          rejection: domain.SessionCleanupRejection(issues: rejection.issues),
          innerError: const SessionCleanupApiRejectedException(rejection: rejection),
        ),
      );

      expect(
        await delete(),
        isA<SessionDeleteRejected>().having((r) => r.rejection.issues.single, "issue", issue),
      );
    });

    test("reports a failed request", () async {
      stubDelete(() async => ApiResponse<void>.error(ApiError.generic()));

      expect(await delete(), isA<SessionDeleteFailed>());
    });
  });

  group("mark read or unread", () {
    test("applies the change to the tracker before the bridge answers", () async {
      when(
        () => sessionRepository.markSessionSeen(sessionId: "s1", read: true),
      ).thenAnswer((_) async => ApiResponse.success(null));

      final mark = actions.markSessionSeen(projectId: projectId, sessionId: "s1", read: true);
      expect(unseen.currentSessionUnseen[projectId]?["s1"]?.unseen, isFalse);
      await mark;

      expect(unseen.currentSessionUnseen[projectId]?["s1"]?.unseen, isFalse);
    });

    test("a failed request restores the tracker's previous value", () async {
      when(
        () => sessionRepository.markSessionSeen(sessionId: "s1", read: false),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
      unseen.emitSessionUnseen({
        projectId: {"s1": (unseen: false, lastUserActivityAt: 42)},
      });

      await actions.markSessionSeen(projectId: projectId, sessionId: "s1", read: false);

      expect(unseen.currentSessionUnseen[projectId]?["s1"], (unseen: false, lastUserActivityAt: 42));
    });

    test("a thrown request drops an entry the tracker did not have", () async {
      when(() => sessionRepository.markSessionSeen(sessionId: "s1", read: true)).thenThrow(StateError("transport"));

      await actions.markSessionSeen(projectId: projectId, sessionId: "s1", read: true);

      expect(unseen.currentSessionUnseen[projectId]?.containsKey("s1"), isFalse);
    });
  });

  group("sendToSession", () {
    void stubSend(Future<SendToSessionResult> Function() answer) => when(
      () => sessionRepository.sendToSession(sourceSessionId: "source", targetSessionId: "target"),
    ).thenAnswer((_) => answer());

    Future<SendToSessionResult> send() =>
        actions.sendToSession(sourceSessionId: "source", sourcePluginId: "claude", targetSessionId: "target");

    List<ProductAnalyticsEvent> reportedEvents() => verify(
      () => analytics.logEvent(
        event: captureAny(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).captured.cast<ProductAnalyticsEvent>();

    // Each outcome reaches the caller as the repository gave it, and is
    // reported once with the source's harness.
    final outcomes = <(SendToSessionResult, AnalyticsSessionSendOutcome)>[
      (const SendToSessionSent(), AnalyticsSessionSendOutcome.sent),
      (
        const SendToSessionRefused(code: SendToSessionErrorCode.sourceBusy, message: null),
        AnalyticsSessionSendOutcome.refusedBusy,
      ),
      (
        const SendToSessionRefused(code: SendToSessionErrorCode.sourceAwaitingInput, message: null),
        AnalyticsSessionSendOutcome.refusedBusy,
      ),
      (
        const SendToSessionRefused(code: SendToSessionErrorCode.targetRefused, message: "No."),
        AnalyticsSessionSendOutcome.refusedOther,
      ),
      (
        const SendToSessionRefused(code: SendToSessionErrorCode.targetOptionsUnavailable, message: null),
        AnalyticsSessionSendOutcome.refusedOther,
      ),
      (
        const SendToSessionRefused(code: SendToSessionErrorCode.unknown, message: null),
        AnalyticsSessionSendOutcome.refusedOther,
      ),
      (SendToSessionFailed(error: ApiError.generic()), AnalyticsSessionSendOutcome.failed),
      (const SendToSessionUnsupported(), AnalyticsSessionSendOutcome.unsupported),
      (SendToSessionUnconfirmed(error: ApiError.generic()), AnalyticsSessionSendOutcome.unconfirmed),
    ];
    for (final (result, outcome) in outcomes) {
      test("returns and reports ${result.runtimeType.toString()} as ${outcome.wireValue}", () async {
        stubSend(() async => result);

        expect(await send(), same(result));

        expect(reportedEvents(), [
          isA<SessionSentToSessionEvent>()
              .having((e) => e.harness, "harness", AnalyticsHarness.claudeCode)
              .having((e) => e.outcome, "outcome", outcome),
        ]);
      });
    }

    test("hides the outcome when the app moved to another computer meanwhile, but still reports it", () async {
      stubSend(() async {
        when(() => selectedComputer.targetBridgeId()).thenAnswer((_) async => "computer-b");
        return SendToSessionUnconfirmed(error: ApiError.generic());
      });

      expect(await send(), isA<SendToSessionComputerSwitched>());

      expect(reportedEvents(), [
        isA<SessionSentToSessionEvent>().having(
          (e) => e.outcome,
          "outcome",
          AnalyticsSessionSendOutcome.unconfirmed,
        ),
      ]);
    });

    test("an analytics failure doesn't change the send's result", () async {
      when(
        () => analytics.logEvent(
          event: any(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).thenAnswer((_) async => throw StateError("analytics down"));
      stubSend(() async => const SendToSessionSent());

      expect(await send(), isA<SendToSessionSent>());
    });
  });
}
