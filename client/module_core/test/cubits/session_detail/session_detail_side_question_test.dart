import "dart:async";
import "dart:typed_data";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_composer_mode.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_attachment.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/foundation/models/composer/restored_composer.dart";
import "package:sesori_dart_core/src/foundation/models/side_question_availability.dart";
import "package:sesori_dart_core/src/repositories/composer_draft_repository.dart";
import "package:sesori_dart_core/src/repositories/models/session_prompt_index_result.dart";
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
  final earlier = _message(id: "m1", text: "first prompt");

  setUpAll(registerAllFallbackValues);

  late MockMessageComposerRestoreService restore;
  late ComposerDraftRepository drafts;
  late SessionDetailCubit cubit;

  Future<void> openSession({required SideQuestionAvailability sideQuestions}) async {
    final loadService = MockSessionDetailLoadService();
    final connectionService = MockConnectionService();
    final sessionRepository = MockSessionRepository();
    restore = MockMessageComposerRestoreService();
    drafts = inMemoryComposerDraftRepository();
    final sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
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
      snapshot: _snapshot(messages: [earlier], sideQuestions: sideQuestions),
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
    when(() => restore.restore(sessionId: _sessionId, message: earlier)).thenAnswer(
      (_) async => RestoredComposer(
        draft: ComposerDraft.typed(text: "first prompt"),
        attachments: const [],
        leftOutCount: 0,
      ),
    );

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
      productAnalyticsService: stubbedProductAnalyticsService(),
      feedbackPromptService: FakeFeedbackPromptService(),
      sessionId: _sessionId,
      projectId: "project-1",
      notificationCanceller: MockNotificationCanceller(),
      failureReporter: MockFailureReporter(),
      bridgeSettingsService: stubbedBridgeSettingsService(),
      sseEventTracker: MockSseEventTracker(),
      fileReferenceOpenService: MockFileReferenceOpenService(),
      composerRestore: restore,
      actionService: MockSessionActionService(),
      window: idleSessionWindow(),
      sessionLaunchService: inMemorySessionLaunchService(launchRepository: inMemorySessionLaunchRepository()),
    );
    addTearDown(cubit.close);
    await awaitState(cubit: cubit, predicate: (state) => state is SessionDetailLoaded, description: "loaded");
  }

  SessionDetailLoaded loaded() => switch (cubit.state) {
    final SessionDetailLoaded state => state,
    final other => throw StateError("Expected a loaded session, got $other"),
  };

  const sideQuestion = SessionComposerMode.sideQuestion();
  const normal = SessionComposerMode.normal();
  final command = testCommandInfo();

  test('typing "/btw " in any case enters the mode and the field takes the rest', () async {
    await openSession(sideQuestions: SideQuestionAvailability.available);
    final restorations = loaded().composerRestorations;

    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "/btw"));
    expect(loaded().composerMode, normal, reason: "the space completes the prefix");

    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "/BtW why is this slow?"));

    expect(loaded().composerMode, sideQuestion);
    expect(cubit.composerDraft.text, "why is this slow?");
    expect(loaded().composerRestorations, restorations + 1, reason: "the field takes the stripped text once");
    expect(drafts.readForSession(sessionId: _sessionId).text, "why is this slow?", reason: "drafts are plain text");
  });

  test('"/btw " anywhere but the start stays plain text', () async {
    await openSession(sideQuestions: SideQuestionAvailability.available);

    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "ask /btw later"));

    expect(loaded().composerMode, normal);
    expect(cubit.composerDraft.text, "ask /btw later");
  });

  test('"/btw " stays plain text on a session that cannot ask side questions', () async {
    for (final availability in [
      SideQuestionAvailability.unresolved,
      SideQuestionAvailability.bridgeUpdateRequired,
      SideQuestionAvailability.harnessUnsupported,
    ]) {
      await openSession(sideQuestions: availability);

      cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "/btw why?"));

      expect(loaded().composerMode, normal, reason: "$availability");
      expect(cubit.composerDraft.text, "/btw why?");

      cubit.startSideQuestion();
      expect(loaded().composerMode, normal, reason: "the picker offers no btw row there");
    }
  });

  test("leaving keeps the text, and the mode never comes back with a draft", () async {
    await openSession(sideQuestions: SideQuestionAvailability.available);
    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "/btw what does this do?"));

    cubit.leaveSideQuestion();

    expect(loaded().composerMode, normal);
    expect(cubit.composerDraft.text, "what does this do?");
    expect(drafts.readForSession(sessionId: _sessionId).text, "what does this do?");
  });

  test("staging a command or an image leaves the mode", () async {
    await openSession(sideQuestions: SideQuestionAvailability.available);
    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "/btw why?"));

    cubit.stageCommand(command);
    expect(loaded().composerMode, normal);
    expect(loaded().stagedCommand, command);

    cubit.clearStagedCommand();
    cubit.startSideQuestion();
    expect(loaded().composerMode, sideQuestion);

    cubit.trackComposerAttachments(
      attachments: [ComposerImageAttachment(mime: "image/png", bytes: Uint8List(4), filename: null)],
    );
    expect(loaded().composerMode, normal);
    expect(cubit.composerDraft.text, "why?");
  });

  test("a staged command or images keep the composer out of the mode, typed or picked", () async {
    await openSession(sideQuestions: SideQuestionAvailability.available);
    cubit.stageCommand(command);

    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "/btw why?"));
    expect(loaded().composerMode, normal);
    cubit.startSideQuestion();
    expect(loaded().composerMode, normal);
    expect(loaded().stagedCommand, command, reason: "the command stays staged");

    cubit.clearStagedCommand();
    cubit.trackComposerAttachments(
      attachments: [ComposerImageAttachment(mime: "image/png", bytes: Uint8List(4), filename: null)],
    );
    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "/btw why?"));
    expect(loaded().composerMode, normal);
    cubit.startSideQuestion();
    expect(loaded().composerMode, normal);
  });

  test("the picker's btw row enters the mode keeping what the composer holds", () async {
    await openSession(sideQuestions: SideQuestionAvailability.available);
    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "is this safe?"));
    final restorations = loaded().composerRestorations;

    cubit.startSideQuestion();

    expect(loaded().composerMode, sideQuestion);
    expect(cubit.composerDraft.text, "is this safe?");
    expect(loaded().composerRestorations, restorations, reason: "the field already holds the text");
  });

  test("submitting hands over the trimmed question, clears the draft and leaves the mode", () async {
    await openSession(sideQuestions: SideQuestionAvailability.available);
    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "/btw   "));
    expect(cubit.submitSideQuestion(), isNull, reason: "nothing to ask yet");
    expect(loaded().composerMode, sideQuestion);

    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "  why so many retries?  "));

    expect(cubit.submitSideQuestion(), "why so many retries?");
    expect(loaded().composerMode, normal);
    expect(cubit.composerDraft.text, "");
    expect(drafts.readForSession(sessionId: _sessionId).text, "");
    expect(cubit.submitSideQuestion(), isNull, reason: "a normal composer has no side question to take");
  });

  test("editing a message leaves the mode, and its end brings the text back as plain text", () async {
    await openSession(sideQuestions: SideQuestionAvailability.available);
    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "/btw why?"));

    await cubit.editMessage(message: earlier);
    expect(loaded().composerMode, isA<SessionComposerEditing>());

    cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "/btw edited"));
    expect(loaded().composerMode, isA<SessionComposerEditing>(), reason: "an edit never becomes a side question");

    cubit.cancelEditing();
    expect(loaded().composerMode, normal);
    expect(cubit.composerDraft.text, "why?");
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

SessionDetailSnapshot _snapshot({
  required List<MessageWithParts> messages,
  required SideQuestionAvailability sideQuestions,
}) => SessionDetailSnapshot(
  areOptionsStale: false,
  bridgeQueuedPrompts: const [],
  pluginId: "plugin-1",
  supportsPromptAttachments: true,
  supportsFileUploads: false,
  offersSessionMcp: true,
  sideQuestions: sideQuestions,
  messages: messages,
  olderMessagesCursor: null,
  userMessagesBefore: null,
  awaitingHarnessSync: false,
  pendingQuestions: const [],
  pendingPermissions: const [],
  childSessions: const [],
  statuses: const {_sessionId: SessionStatus.idle()},
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
