import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/interrupted_turn.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_composer_mode.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_notice.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/foundation/models/composer/restored_composer.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/foundation/models/side_question_availability.dart";
import "package:sesori_dart_core/src/repositories/composer_draft_repository.dart";
import "package:sesori_dart_core/src/repositories/models/session_fork_result.dart";
import "package:sesori_dart_core/src/repositories/models/session_prompt_index_result.dart";
import "package:sesori_dart_core/src/repositories/models/session_rewind_result.dart";
import "package:sesori_dart_core/src/services/session_abort_service.dart";
import "package:sesori_dart_core/src/services/session_approval_service.dart";
import "package:sesori_dart_core/src/services/session_auto_continuation_service.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_dart_core/src/services/session_interaction_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

const _sessionId = "session-1";

void main() {
  const connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token", bridgeId: null),
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
  );
  final edited = _message(id: "m1", text: "first prompt");

  setUpAll(registerAllFallbackValues);

  late MockSessionRepository sessionRepository;
  late MockMessageComposerRestoreService restore;
  late MockSessionActionService actions;
  late MockProductAnalyticsService analytics;
  late ComposerDraftRepository drafts;
  late StreamController<SesoriSessionEvent> sessionEvents;
  late SessionDetailCubit cubit;
  late List<SessionDetailNotice> notices;

  Future<void> openSession({required SessionStatus status}) async {
    final loadService = MockSessionDetailLoadService();
    final connectionService = MockConnectionService();
    sessionRepository = MockSessionRepository();
    restore = MockMessageComposerRestoreService();
    actions = MockSessionActionService();
    analytics = stubbedProductAnalyticsService();
    drafts = inMemoryComposerDraftRepository();
    sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
    final globalEvents = StreamController<SseEvent>.broadcast();
    final connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(connectedStatus);
    addTearDown(sessionEvents.close);
    addTearDown(globalEvents.close);
    addTearDown(connectionStatus.close);

    when(() => connectionService.sessionEvents(_sessionId)).thenAnswer((_) => sessionEvents.stream);
    when(() => connectionService.events).thenAnswer((_) => globalEvents.stream);
    when(() => connectionService.status).thenAnswer((_) => connectionStatus);
    when(() => connectionService.currentStatus).thenAnswer((_) => connectionStatus.value);
    when(
      () => loadService.loadPromptIndex(sessionId: _sessionId),
    ).thenAnswer((_) async => const SessionPromptIndexUnsupported());
    final snapshot = SessionDetailLoadResult.loaded(
      snapshot: _snapshot(messages: [edited], status: status),
    );
    when(
      () => loadService.load(
        session: any(named: "session"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer((_) async => snapshot);
    when(
      () => loadService.reload(
        session: any(named: "session"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer((_) async => snapshot);
    when(() => restore.restore(sessionId: _sessionId, message: edited)).thenAnswer(
      (_) async => RestoredComposer(
        draft: ComposerDraft.typed(text: "first prompt"),
        attachments: const [],
        leftOutCount: 1,
      ),
    );
    when(
      () => sessionRepository.abortSession(sessionId: _sessionId, subAgents: SessionAbortSubAgentPolicy.stop),
    ).thenAnswer((_) async => SuccessResponse(true));

    cubit = SessionDetailCubit(
      connectionService,
      pluginManagementService: stubbedPluginManagementService(),
      interactionCalculator: const SessionInteractionCalculator(),
      loadService: loadService,
      sessionAbortService: SessionAbortService(repository: sessionRepository),
      autoContinuationService: SessionAutoContinuationService(repository: sessionRepository),
      approvalService: SessionApprovalService(repository: sessionRepository),
      promptDispatcher: sessionRepository,
      permissionRepository: MockPermissionRepository(),
      sessionViewingService: stubbedSessionViewingService(),
      lifecycleSource: FakeLifecycleSource(),
      composerDraftRepository: drafts,
      productAnalyticsService: analytics,
      feedbackPromptService: FakeFeedbackPromptService(),
      sessionId: _sessionId,
      projectId: "project-1",
      notificationCanceller: MockNotificationCanceller(),
      failureReporter: MockFailureReporter(),
      bridgeSettingsService: stubbedBridgeSettingsService(),
      sseEventTracker: MockSseEventTracker(),
      fileReferenceOpenService: MockFileReferenceOpenService(),
      composerRestore: restore,
      actionService: actions,
      window: idleSessionWindow(),
      sessionLaunchService: inMemorySessionLaunchService(launchRepository: inMemorySessionLaunchRepository()),
    );
    addTearDown(cubit.close);
    notices = [];
    final noticeSub = cubit.noticeStream.listen(notices.add);
    addTearDown(noticeSub.cancel);
    await awaitState(cubit: cubit, predicate: (state) => state is SessionDetailLoaded, description: "loaded");
  }

  void answerRewind(SessionRewindResult result) {
    when(
      () => sessionRepository.rewindSession(
        sessionId: any(named: "sessionId"),
        messageId: any(named: "messageId"),
        promptId: any(named: "promptId"),
        text: any(named: "text"),
        attachments: any(named: "attachments"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
      ),
    ).thenAnswer((_) async => result);
  }

  List<String> rewoundPromptIds() => verify(
    () => sessionRepository.rewindSession(
      sessionId: _sessionId,
      messageId: "m1",
      promptId: captureAny(named: "promptId"),
      text: "first prompt, edited",
      attachments: const [],
      agent: any(named: "agent"),
      model: any(named: "model"),
      variant: any(named: "variant"),
      fastMode: any(named: "fastMode"),
    ),
  ).captured.cast<String>();

  SessionDetailLoaded loaded() => cubit.state as SessionDetailLoaded;

  test("editing takes up the message and Cancel gives back what the composer held", () async {
    await openSession(status: const SessionStatus.idle());
    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "half a follow-up"));
    final restorations = loaded().composerRestorations;

    await cubit.editMessage(message: edited);

    expect(
      loaded().composerMode,
      const SessionComposerMode.editing(messageId: "m1", phase: SessionEditPhase.composing, leftOutCount: 1),
    );
    expect(cubit.composerDraft.text, "first prompt");
    expect(loaded().composerRestorations, restorations + 1, reason: "the composer takes up the message once");

    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "first prompt, edi"));
    expect(
      drafts.readForSession(sessionId: _sessionId).text,
      "half a follow-up",
      reason: "an edit's words stay off the saved draft",
    );

    cubit.cancelEditing();

    expect(loaded().composerMode, const SessionComposerMode.normal());
    expect(cubit.composerDraft.text, "half a follow-up");
    expect(loaded().composerRestorations, restorations + 2);
  });

  test("an accepted edit ends the edit and reports its outcome", () async {
    await openSession(status: const SessionStatus.idle());
    answerRewind(const SessionRewindAccepted());
    await cubit.editMessage(message: edited);

    await cubit.resendEdit(text: " first prompt, edited ", attachments: const []);

    expect(rewoundPromptIds(), hasLength(1));
    expect(loaded().composerMode, const SessionComposerMode.normal());
    expect(cubit.composerDraft.text, "", reason: "the composer held nothing before the edit");
    verify(
      () => analytics.logEvent(
        event: const SessionMessageEditedEvent(
          harness: AnalyticsHarness.other,
          outcome: AnalyticsMessageEditOutcome.succeeded,
        ),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).called(1);
  });

  test("a refusal keeps the edit and says why; a retry after a lost answer reuses its prompt id", () async {
    await openSession(status: const SessionStatus.idle());
    await cubit.editMessage(message: edited);
    answerRewind(const SessionRewindUnavailable(reason: "No checkpoint for this message"));

    await cubit.resendEdit(text: "first prompt, edited", attachments: const []);
    await pumpEventQueue();

    expect(
      notices.last,
      isA<SessionDetailEditRefused>().having((n) => n.reason, "reason", "No checkpoint for this message"),
    );
    expect((loaded().composerMode as SessionComposerEditing).phase, SessionEditPhase.composing);

    answerRewind(SessionRewindFailed(error: ApiError.generic()));
    await cubit.resendEdit(text: "first prompt, edited", attachments: const []);
    await cubit.resendEdit(text: "first prompt, edited", attachments: const []);
    await pumpEventQueue();

    expect(notices.last, isA<SessionDetailEditFailed>());
    expect(rewoundPromptIds().toSet(), hasLength(1), reason: "the bridge never applies one edit twice");
  });

  test("a fork from your own message hands its text to the fork's composer, a failed one keeps nothing", () async {
    await openSession(status: const SessionStatus.idle());
    void answerFork(SessionForkResult result) => when(
      () => actions.forkSession(
        sessionId: _sessionId,
        pluginId: any(named: "pluginId"),
        point: const ForkPoint.beforeMessage(messageId: "m1"),
        recreateFromBase: false,
      ),
    ).thenAnswer((_) async => result);
    Future<SessionForkResult> fork() => cubit.forkSession(
      point: const ForkPoint.beforeMessage(messageId: "m1"),
      ownMessage: edited,
      recreateFromBase: false,
    );

    answerFork(SessionForkFailed(error: ApiError.generic()));
    expect(await fork(), isA<SessionForkFailed>());
    expect(drafts.readForSession(sessionId: "fork-1").text, isEmpty);

    answerFork(SessionForked(session: testSession(id: "fork-1")));
    expect(await fork(), isA<SessionForked>());
    expect(drafts.readForSession(sessionId: "fork-1").text, "first prompt");
    expect(cubit.composerDraft.text, isEmpty, reason: "the origin's composer is left alone");
  });

  test("an edit changed after a lost answer goes out under a new prompt id", () async {
    await openSession(status: const SessionStatus.idle());
    await cubit.editMessage(message: edited);
    answerRewind(SessionRewindFailed(error: ApiError.generic()));
    await cubit.resendEdit(text: "first prompt, edited", attachments: const []);

    answerRewind(const SessionRewindAccepted());
    await cubit.resendEdit(text: "first prompt, edited twice", attachments: const []);

    final promptIds = verify(
      () => sessionRepository.rewindSession(
        sessionId: _sessionId,
        messageId: "m1",
        promptId: captureAny(named: "promptId"),
        text: any(named: "text"),
        attachments: any(named: "attachments"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
      ),
    ).captured;
    expect(promptIds.toSet(), hasLength(2), reason: "the bridge would answer the first id without the change");
    expect(loaded().composerMode, const SessionComposerMode.normal());
  });

  test("an open edit locks Continue on a cut-off turn and sends nothing", () async {
    await openSession(status: const SessionStatus.idle());
    sessionEvents.add(
      SesoriSessionUpdated(
        info: testSession(id: _sessionId).copyWith(
          interruption: const SessionInterruption(afterMessageId: "m1", unacknowledged: false),
        ),
      ),
    );
    await awaitState(
      cubit: cubit,
      predicate: (state) => state is SessionDetailLoaded && state.interruptedTurn is InterruptedTurnShown,
      description: "interrupted line shown",
    );

    await cubit.editMessage(message: edited);

    expect(await cubit.continueInterruptedTurn(), InterruptedTurnContinueRefusal.editOpen);
    verifyNever(
      () => sessionRepository.sendMessage(
        promptId: any(named: "promptId"),
        sessionId: any(named: "sessionId"),
        text: any(named: "text"),
        attachments: any(named: "attachments"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        commandSource: any(named: "commandSource"),
      ),
    );
  });

  test("Resend during a turn offers to stop first, and Stop and resend sends once the session is idle", () async {
    await openSession(status: const SessionStatus.busy(since: null));
    answerRewind(const SessionRewindAccepted());
    await cubit.editMessage(message: edited);

    await cubit.resendEdit(text: "first prompt, edited", attachments: const []);
    await pumpEventQueue();

    expect(notices.last, isA<SessionDetailEditBusy>());
    verifyNever(
      () => sessionRepository.rewindSession(
        sessionId: any(named: "sessionId"),
        messageId: any(named: "messageId"),
        promptId: any(named: "promptId"),
        text: any(named: "text"),
        attachments: any(named: "attachments"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
      ),
    );

    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "first prompt, edited"));
    final resent = cubit.stopAndResendEdit();
    await pumpEventQueue();
    expect((loaded().composerMode as SessionComposerEditing).phase, SessionEditPhase.stopping);
    sessionEvents.add(const SesoriSessionStatus(sessionID: _sessionId, status: SessionStatus.idle()));
    await resent;

    verify(
      () => sessionRepository.abortSession(sessionId: _sessionId, subAgents: SessionAbortSubAgentPolicy.stop),
    ).called(1);
    expect(rewoundPromptIds(), hasLength(1));
    expect(loaded().composerMode, const SessionComposerMode.normal());
  });
}

MessageWithParts _message({required String id, required String text}) => MessageWithParts(
  info: Message.user(
    invocation: null,
    handoff: null,
    promptId: null,
    id: id,
    sessionID: _sessionId,
    agent: null,
    time: const MessageTime(created: 1, completed: null),
  ),
  parts: [
    MessagePart.text(id: "$id-text", sessionID: _sessionId, messageID: id, text: text),
  ],
);

SessionDetailSnapshot _snapshot({required List<MessageWithParts> messages, required SessionStatus status}) =>
    SessionDetailSnapshot(
      areOptionsStale: false,
      bridgeQueuedPrompts: const [],
      pluginId: "plugin-1",
      supportsPromptAttachments: true,
      supportsFileUploads: false,
      offersSessionMcp: true,
      sideQuestions: SideQuestionAvailability.unresolved,
      messages: messages,
      olderMessagesCursor: null,
      userMessagesBefore: null,
      awaitingHarnessSync: false,
      pendingQuestions: const [],
      pendingPermissions: const [],
      childSessions: const [],
      statuses: {_sessionId: status},
      agents: const [],
      providerData: null,
      commands: const [],
      canonicalSessionTitle: null,
      promptDefaults: null,
      isRootSession: true,
      isArchived: false,
      cannotContinueMessage: null,
      namesCommandInvocations: false,
      supportsRewind: true,
      supportsFork: false,
    );
