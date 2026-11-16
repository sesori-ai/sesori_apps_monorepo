import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_discovery_snapshot.dart";
import "package:sesori_dart_core/src/repositories/models/send_to_session_result.dart";
import "package:sesori_dart_core/src/repositories/models/session_cleanup_rejection.dart" as domain;
import "package:sesori_dart_core/src/repositories/models/session_fork_result.dart";
import "package:sesori_dart_core/src/services/models/session_cleanup_outcome.dart";
import "package:sesori_dart_core/src/services/models/session_delete_result.dart";
import "package:sesori_dart_core/src/services/selected_computer_service.dart";
import "package:sesori_dart_core/src/services/session_action_service.dart";
import "package:sesori_dart_core/src/services/session_cleanup_service.dart";
import "package:sesori_dart_core/src/services/session_send_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

class _MockSelectedComputerService() extends Mock implements SelectedComputerService;

void main() {
  setUpAll(registerAllFallbackValues);

  const projectId = "project-1";
  late MockSessionRepository sessionRepository;
  late MockPluginRepository plugins;
  late FakeSessionUnseenTracker unseen;
  late MockFailureReporter failureReporter;
  late SessionActionService actions;
  late _MockSelectedComputerService selectedComputer;
  late MockProductAnalyticsService analytics;
  late SessionSendTracker sendTracker;

  setUp(() {
    analytics = stubbedProductAnalyticsService();
    sendTracker = SessionSendTracker();
    selectedComputer = _MockSelectedComputerService();
    when(() => selectedComputer.targetBridgeId()).thenAnswer((_) async => "computer-a");
    sessionRepository = MockSessionRepository();
    plugins = MockPluginRepository();
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
      sendTracker: sendTracker,
      sessionRepository: sessionRepository,
      sessionCleanupService: SessionCleanupService(repository: sessionRepository),
      sessionUnseenTracker: unseen,
      failureReporter: failureReporter,
      selectedComputerService: selectedComputer,
      productAnalyticsService: analytics,
      pluginRepository: plugins,
    );
  });

  tearDown(() {
    unseen.onDispose();
    sendTracker.onDispose();
  });

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

    Future<SendToSessionResult> send() => actions.sendToSession(
      targetTitle: "Target",
      sourceSessionId: "source",
      sourcePluginId: "claude",
      targetSessionId: "target",
    );

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
        return const SendToSessionSent();
      });

      expect(await send(), isA<SendToSessionComputerSwitched>());

      expect(reportedEvents(), [
        isA<SessionSentToSessionEvent>().having((e) => e.outcome, "outcome", AnalyticsSessionSendOutcome.sent),
      ]);
    });

    group("whose answer was lost", () {
      MessageWithParts user({
        required String id,
        required String sessionId,
        required MessageHandoff? handoff,
        required int created,
      }) => MessageWithParts(
        info: Message.user(
          id: id,
          sessionID: sessionId,
          agent: null,
          time: MessageTime(created: created, completed: null),
          promptId: null,
          invocation: null,
          handoff: handoff,
        ),
        parts: const [],
      );

      const request = MessageHandoff.sent(targetSessionId: "target", targetTitle: null);
      const notSent = MessageHandoff.notSent(targetSessionId: "target", targetTitle: null);
      const received = MessageHandoff.received(
        sourceSessionId: "source",
        sourceTitle: null,
        summary: "Summary",
        transcriptPath: "/transcript.md",
      );

      // Each session's newest page, or null while the app is offline.
      late Map<String, List<MessageWithParts>?> pages;

      setUp(() {
        pages = {"source": null, "target": null};
        when(
          () => sessionRepository.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: null,
            storedOnly: false,
          ),
        ).thenAnswer((invocation) async {
          final messages = pages[invocation.namedArguments[#sessionId]];
          return messages == null
              ? ApiResponse.error(ApiError.generic())
              : ApiResponse.success(
                  MessageWithPartsResponse(
                    messages: messages,
                    nextCursor: null,
                    replayedPromptDefaults: null,
                    userMessagesBefore: null,
                    cannotContinueMessage: null,
                  ),
                );
        });
        stubSend(() async => SendToSessionUnconfirmed(error: ApiError.generic()));
      });

      /// Sends, lets [elapsed] pass after [meanwhile], and returns the result
      /// if it came by then.
      SendToSessionResult? sendFor({required Duration elapsed, void Function(FakeAsync async)? meanwhile}) {
        SendToSessionResult? result;
        fakeAsync((async) {
          unawaited(send().then((value) => result = value));
          meanwhile?.call(async);
          async.elapse(elapsed);
        });
        return result;
      }

      test("is sent once the target holds the handoff, after the app is back online", () {
        final result = sendFor(
          elapsed: const Duration(seconds: 15),
          meanwhile: (async) {
            async.elapse(const Duration(seconds: 25));
            pages["source"] = [user(id: "request", sessionId: "source", handoff: request, created: 20)];
            // Still being written: the target holds only an earlier send's handoff.
            pages["target"] = [user(id: "earlier", sessionId: "target", handoff: received, created: 10)];
            async.elapse(const Duration(seconds: 10));
            pages["target"] = [
              user(id: "earlier", sessionId: "target", handoff: received, created: 10),
              user(id: "prompt", sessionId: "target", handoff: received, created: 30),
              user(id: "next", sessionId: "target", handoff: null, created: 40),
            ];
          },
        );

        expect(result, isA<SendToSessionSent>());
        expect(reportedEvents(), [
          isA<SessionSentToSessionEvent>().having((e) => e.outcome, "outcome", AnalyticsSessionSendOutcome.sent),
        ]);
      });

      test("is not sent on the strength of a handoff an earlier send left in the target", () {
        pages["source"] = [user(id: "request", sessionId: "source", handoff: request, created: 20)];
        pages["target"] = [user(id: "earlier", sessionId: "target", handoff: received, created: 10)];

        expect(sendFor(elapsed: const Duration(seconds: 30)), isNull);
      });

      test("is not sent when the source's newest request for the target is marked not sent", () {
        pages["source"] = [
          user(id: "earlier", sessionId: "source", handoff: request, created: 10),
          user(id: "request", sessionId: "source", handoff: notSent, created: 30),
        ];
        // An earlier send's handoff doesn't count for this one.
        pages["target"] = [user(id: "prompt", sessionId: "target", handoff: received, created: 20)];

        expect(sendFor(elapsed: const Duration(seconds: 10)), isA<SendToSessionNotSent>());
        expect(reportedEvents(), [
          isA<SessionSentToSessionEvent>().having(
            (e) => e.outcome,
            "outcome",
            AnalyticsSessionSendOutcome.refusedOther,
          ),
        ]);
      });

      test("stays unconfirmed when no outcome shows within the bridge's wait", () {
        pages["source"] = [user(id: "request", sessionId: "source", handoff: request, created: 20)];
        pages["target"] = [];

        expect(sendFor(elapsed: const Duration(minutes: 14, seconds: 50)), isNull);
        expect(sendFor(elapsed: const Duration(minutes: 15)), isA<SendToSessionUnconfirmed>());
        expect(
          reportedEvents(),
          [
            isA<SessionSentToSessionEvent>().having(
              (e) => e.outcome,
              "outcome",
              AnalyticsSessionSendOutcome.unconfirmed,
            ),
          ],
        );
      });

      test("stops looking when the app moves to another computer", () {
        final result = sendFor(
          elapsed: const Duration(seconds: 10),
          meanwhile: (_) => when(() => selectedComputer.targetBridgeId()).thenAnswer((_) async => "computer-b"),
        );

        expect(result, isA<SendToSessionComputerSwitched>());
        verifyNever(
          () => sessionRepository.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
            storedOnly: any(named: "storedOnly"),
          ),
        );
      });
    });

    test("shows the source as being sent until the send ends", () async {
      final answer = Completer<SendToSessionResult>();
      stubSend(() => answer.future);

      final result = send();
      await pumpEventQueue();

      expect(sendTracker.currentSending["source"]?.targetTitle, "Target");
      answer.complete(const SendToSessionSent());
      await result;
      expect(sendTracker.currentSending, isEmpty);
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

  group("fork", () {
    PluginMetadata plugin({required String id, required Set<SessionBranchingOperation> branching}) => PluginMetadata(
      id: id,
      displayName: id,
      isDefault: false,
      state: PluginLifecycleState.ready,
      actionHint: null,
      failureBlock: null,
      mcpScopes: null,
      supportsPromptAttachments: false,
      failureReason: null,
      sessionBranching: branching,
    );

    test("a top-level session forks when its harness lists fork", () async {
      when(() => plugins.listPlugins()).thenAnswer(
        (_) async => ApiResponse.success(
          PluginDiscoverySnapshot(
            bridgeId: "bridge",
            supportsSessionOptions: true,
            supportsFileUploads: false,
            supportsSideQuestions: false,
            plugins: [
              plugin(id: "claude", branching: {SessionBranchingOperation.fork}),
              plugin(id: "opencode", branching: const {}),
            ],
          ),
        ),
      );
      await actions.refreshForkCapabilities();

      expect(
        actions.canFork(
          session: testSession(id: "s1", pluginId: "claude"),
        ),
        isTrue,
      );
      expect(
        actions.canFork(
          session: testSession(id: "s2", pluginId: "opencode"),
        ),
        isFalse,
      );
      expect(
        actions.canFork(
          session: testSession(id: "s3", pluginId: "claude", parentID: "s1"),
        ),
        isFalse,
      );
    });

    test("a failed listing offers no Fork", () async {
      when(() => plugins.listPlugins()).thenAnswer(
        (_) async => ApiResponse.success(
          PluginDiscoverySnapshot(
            bridgeId: "bridge",
            supportsSessionOptions: true,
            supportsFileUploads: false,
            supportsSideQuestions: false,
            plugins: [
              plugin(id: "claude", branching: {SessionBranchingOperation.fork}),
            ],
          ),
        ),
      );
      await actions.refreshForkCapabilities();
      when(() => plugins.listPlugins()).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
      await actions.refreshForkCapabilities();

      expect(
        actions.canFork(
          session: testSession(id: "s1", pluginId: "claude"),
        ),
        isFalse,
      );
    });

    final outcomes = <(SessionForkResult, AnalyticsSessionForkOutcome)>[
      (SessionForked(session: testSession(id: "fork")), AnalyticsSessionForkOutcome.succeeded),
      (const SessionForkUnavailable(reason: null), AnalyticsSessionForkOutcome.branchPointUnavailable),
      (const SessionForkNothingToFork(), AnalyticsSessionForkOutcome.refused),
      (const SessionForkWorktreeBranchMissing(), AnalyticsSessionForkOutcome.refused),
      (const SessionForkRejected(reason: "no"), AnalyticsSessionForkOutcome.refused),
      (SessionForkFailed(error: ApiError.generic()), AnalyticsSessionForkOutcome.failed),
    ];
    for (final (result, outcome) in outcomes) {
      test("returns and reports ${result.runtimeType.toString()} as ${outcome.wireValue}", () async {
        when(
          () =>
              sessionRepository.forkSession(sessionId: "s1", point: const ForkPoint.latest(), recreateFromBase: false),
        ).thenAnswer((_) async => result);

        expect(
          await actions.forkSession(
            sessionId: "s1",
            pluginId: "claude",
            point: const ForkPoint.latest(),
            recreateFromBase: false,
          ),
          same(result),
        );

        final reported = verify(
          () => analytics.logEvent(
            event: captureAny(named: "event"),
            occurredAtUtc: any(named: "occurredAtUtc"),
          ),
        ).captured;
        expect(reported, [
          isA<SessionForkedEvent>()
              .having((e) => e.harness, "harness", AnalyticsHarness.claudeCode)
              .having((e) => e.outcome, "outcome", outcome),
        ]);
      });
    }
  });
}
