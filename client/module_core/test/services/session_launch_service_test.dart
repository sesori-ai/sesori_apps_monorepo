import "dart:async";
import "dart:typed_data";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  late MockSessionRepository sessionRepository;
  late SessionLaunchStorage storage;
  late SessionLaunchRepository launchRepository;
  late FakeFeedbackPromptService feedbackPromptService;
  late MockProductAnalyticsService productAnalyticsService;
  late NewSessionSelectionTracker selectionTracker;
  late FakeAuthSession authSession;
  late SessionLaunchService service;
  late Completer<ApiResponse<Session>> response;
  late List<SessionLaunchOutcome> outcomes;
  final submission = NewSessionSubmissionSnapshot.text(
    draft: ComposerDraft.typed(text: "Hello"),
    attachments: const [],
  );

  setUpAll(registerAllFallbackValues);

  setUp(() {
    sessionRepository = MockSessionRepository();
    storage = SessionLaunchStorage();
    launchRepository = SessionLaunchRepository(storage: storage);
    feedbackPromptService = FakeFeedbackPromptService();
    productAnalyticsService = stubbedProductAnalyticsService();
    selectionTracker = NewSessionSelectionTracker();
    authSession = FakeAuthSession(initialState: const AuthState.initial());
    addTearDown(authSession.dispose);
    service = SessionLaunchService(
      sessionRepository: sessionRepository,
      launchRepository: launchRepository,
      feedbackPromptService: feedbackPromptService,
      productAnalyticsService: productAnalyticsService,
      selectionTracker: selectionTracker,
      authSession: authSession,
    );
    response = Completer<ApiResponse<Session>>();
    when(
      () => sessionRepository.createSessionWithMessage(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        attachments: any(named: "attachments"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => response.future);
    outcomes = [];
    final subscription = service.outcomes.listen(outcomes.add);
    addTearDown(subscription.cancel);
  });

  Future<void> launch({ProjectKind projectKind = ProjectKind.folder, String? agent}) => service.launch(
    launchId: "launch-1",
    projectId: "project-1",
    pluginId: "plugin-1",
    startedAt: DateTime.utc(2026, 9, 27),
    projectName: null,
    projectKind: projectKind,
    submission: submission,
    agent: agent,
    model: null,
    variant: null,
    fastMode: false,
    dedicatedWorktree: false,
  );

  test("a launch whose composer left mid-create still finishes everything it owes", () async {
    selectionTracker.recordAgent(pluginId: "plugin-1", agentName: "build");
    final pending = launch(agent: "build");
    // The composer closes before the bridge answers.
    service.releaseHandoff(launchId: "launch-1");

    response.complete(ApiResponse.success(testSession(id: "session-1")));
    await pending;
    await Future<void>.delayed(Duration.zero);

    expect(outcomes, [
      SessionLaunchOutcome.succeeded(
        launchId: "launch-1",
        session: testSession(id: "session-1"),
      ),
    ]);
    expect(selectionTracker.read(pluginId: "plugin-1"), isNull);
    expect(feedbackPromptService.failedSessions, isEmpty);
    verify(
      () => productAnalyticsService.logEvent(
        event: const ProductAnalyticsEvent.sessionCreatedWithMessage(
          submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
          workspaceKind: AnalyticsWorkspaceKind.project,
        ),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).called(1);
    expect(storage.readAll(), isEmpty);
  });

  test("a dictated first message reaches the bridge marked", () async {
    final pending = service.launch(
      launchId: "launch-1",
      projectId: "project-1",
      pluginId: "plugin-1",
      startedAt: DateTime.utc(2026, 9, 27),
      projectName: null,
      projectKind: ProjectKind.folder,
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft(
          text: "Hello",
          voiceSpans: [VoiceOriginSpan(start: 0, end: 5)],
        ),
        attachments: const [],
      ),
      agent: null,
      model: null,
      variant: null,
      fastMode: false,
      dedicatedWorktree: false,
    );
    response.complete(ApiResponse.success(testSession(id: "session-1")));
    await pending;

    verify(
      () => sessionRepository.createSessionWithMessage(
        projectId: "project-1",
        pluginId: "plugin-1",
        text: wrapDictatedText(text: "Hello"),
        attachments: const [],
        agent: null,
        model: null,
        variant: null,
        fastMode: false,
        command: null,
        dedicatedWorktree: false,
      ),
    ).called(1);
  });

  test("success keeps a selection the user changed while the session was being created", () async {
    selectionTracker.recordAgent(pluginId: "plugin-1", agentName: "build");
    final pending = launch(agent: "build");
    selectionTracker.recordAgent(pluginId: "plugin-1", agentName: "plan");

    response.complete(ApiResponse.success(testSession(id: "session-1")));
    await pending;

    expect(selectionTracker.read(pluginId: "plugin-1")?.agentName, "plan");
  });

  test("success keeps a pick the project could not apply, for a project that can", () async {
    selectionTracker.recordAgent(pluginId: "plugin-1", agentName: "plan");
    // The project lacks "plan", so the session started on its default.
    final pending = launch(agent: "build");

    response.complete(ApiResponse.success(testSession(id: "session-1")));
    await pending;

    expect(selectionTracker.read(pluginId: "plugin-1")?.agentName, "plan");
  });

  group("prompt_files_sent on create", () {
    final image = ComposerImageAttachment(mime: "image/png", bytes: Uint8List(1), filename: "shot.png");
    ComposerFileAttachment file({required ComposerAttachmentSource source}) =>
        ComposerFileAttachment(bytes: Uint8List(1), filename: "notes.pdf", source: source);

    Future<void> launchWith({required List<ComposerAttachment> attachments}) => service.launch(
      launchId: "launch-1",
      projectId: "project-1",
      pluginId: "plugin-1",
      startedAt: DateTime.utc(2026, 9, 27),
      projectName: null,
      projectKind: ProjectKind.folder,
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Hello"),
        attachments: attachments,
      ),
      agent: null,
      model: null,
      variant: null,
      fastMode: false,
      dedicatedWorktree: false,
    );

    void verifyNoFilesSent() => verifyNever(
      () => productAnalyticsService.logEvent(
        event: any(named: "event", that: isA<PromptFilesSentEvent>()),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    );

    test("follows the created event when the first message carries files", () async {
      final pending = launchWith(
        attachments: [
          image,
          file(source: ComposerAttachmentSource.drop),
          file(source: ComposerAttachmentSource.paste),
        ],
      );
      response.complete(ApiResponse.success(testSession(id: "session-1")));
      await pending;

      verifyInOrder([
        () => productAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.sessionCreatedWithMessage(
            submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
            workspaceKind: AnalyticsWorkspaceKind.project,
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
        () => productAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.promptFilesSent(
            fileCount: AnalyticsFileCountBucket.twoToFour,
            source: AnalyticsFileSource.mixed,
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ]);
    });

    test("is not reported for a first message holding only inline images", () async {
      final pending = launchWith(attachments: [image]);
      response.complete(ApiResponse.success(testSession(id: "session-1")));
      await pending;

      verifyNoFilesSent();
    });

    test("is not reported when the create fails", () async {
      final pending = launchWith(attachments: [file(source: ComposerAttachmentSource.picker)]);
      response.complete(ApiResponse.error(ApiError.generic()));
      await pending;

      verifyNoFilesSent();
    });
  });

  test("a failed create publishes its reason, reports it and logs the original error", () async {
    final records = <LogRecord>[];
    setLogSink(sink: _RecordingSink(records: records));
    addTearDown(() => setLogSink(sink: const StdoutLogSink()));
    selectionTracker.recordAgent(pluginId: "plugin-1", agentName: "build");
    final pending = launch(agent: "build");

    response.complete(ApiResponse.error(ApiError.generic()));
    await pending;
    await Future<void>.delayed(Duration.zero);

    expect(outcomes, [
      const SessionLaunchOutcome.failedWhileComposing(
        launchId: "launch-1",
        reason: RemoteFailureReason.unknown,
        followUps: [],
      ),
    ]);
    expect(records.single.message, "New session creation failed");
    expect(records.single.diagnosticError, isNotNull);
    // No session exists yet, so no session's points are dropped.
    expect(feedbackPromptService.failedSessions, isEmpty);
    verify(
      () => productAnalyticsService.logEvent(
        event: const ProductAnalyticsEvent.sessionCreationFailed(
          failureReason: AnalyticsSessionCreationFailureReason.unknown,
          workspaceKind: AnalyticsWorkspaceKind.project,
        ),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).called(1);
    expect(selectionTracker.read(pluginId: "plugin-1"), isNotNull);
    expect(storage.readAll(), isEmpty);
  });

  test("a No project launch reports no_project whether it succeeds or fails", () async {
    response.complete(ApiResponse.success(testSession(id: "session-1")));
    await launch(projectKind: ProjectKind.scratch);
    response = Completer();
    response.complete(ApiResponse.error(ApiError.generic()));
    await launch(projectKind: ProjectKind.scratch);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => productAnalyticsService.logEvent(
        event: const ProductAnalyticsEvent.sessionCreatedWithMessage(
          submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
          workspaceKind: AnalyticsWorkspaceKind.noProject,
        ),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).called(1);
    verify(
      () => productAnalyticsService.logEvent(
        event: const ProductAnalyticsEvent.sessionCreationFailed(
          failureReason: AnalyticsSessionCreationFailureReason.unknown,
          workspaceKind: AnalyticsWorkspaceKind.noProject,
        ),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).called(1);
  });

  test("signing out drops every launch, so a create that fails afterwards reaches no one", () async {
    var discarded = 0;
    final discards = service.discarded.listen((_) => discarded++);
    addTearDown(discards.cancel);
    final pending = launch();
    service.releaseHandoff(launchId: "launch-1");

    authSession.emit(const AuthState.unauthenticated());
    await Future<void>.delayed(Duration.zero);
    expect(service.launches.value, isEmpty, reason: "no launching row outlives the account");
    expect(discarded, 1, reason: "the shell drops an alert it has not shown yet or still shows");

    response.complete(ApiResponse.error(ApiError.generic()));
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(outcomes, isEmpty, reason: "the old project's name never reaches the login screen or the next account");
  });

  group("follow-ups", () {
    late List<String> sentPromptIds;
    late List<ApiResponse<void>> sendResponses;

    QueuedSessionSubmission followUp({required String promptId}) => QueuedSessionSubmission.text(
      promptId: promptId,
      text: "and then $promptId",
      inputMode: ComposerInputMode.typed,
      attachments: const [],
      agent: null,
      agentModel: null,
      fastMode: false,
    );

    setUp(() {
      sentPromptIds = [];
      sendResponses = [];
      when(
        () => sessionRepository.sendMessage(
          sessionId: "session-1",
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
        ),
      ).thenAnswer((invocation) async {
        sentPromptIds.add(invocation.namedArguments[#promptId] as String);
        return sendResponses.isEmpty ? ApiResponse.success(null) : sendResponses.removeAt(0);
      });
    });

    Future<void> launchWithFollowUps() async {
      final pending = launch();
      service.addFollowUp(
        launchId: "launch-1",
        submission: followUp(promptId: "prm_a"),
      );
      service.addFollowUp(
        launchId: "launch-1",
        submission: followUp(promptId: "prm_b"),
      );
      // The composer closes before the bridge answers; nothing watches.
      service.releaseHandoff(launchId: "launch-1");
      expect(sentPromptIds, isEmpty, reason: "follow-ups wait for the session");
      response.complete(ApiResponse.success(testSession(id: "session-1")));
      await pending;
      await Future<void>.delayed(Duration.zero);
    }

    test("are delivered in press order once the session exists, with no screen open", () async {
      await launchWithFollowUps();

      expect(sentPromptIds, ["prm_a", "prm_b"]);
      expect(storage.readAll(), isEmpty);
      expect(feedbackPromptService.failedSessions, isEmpty);
      verify(
        () => productAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.sessionMessageSent(
            submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).called(2);
    });

    test("a follow-up with files reports them once it is accepted, not when it fails", () async {
      sendResponses.add(ApiResponse.error(ApiError.generic()));
      final pending = launch();
      service.addFollowUp(
        launchId: "launch-1",
        submission: QueuedSessionSubmission.text(
          promptId: "prm_a",
          text: "and then this",
          inputMode: ComposerInputMode.typed,
          attachments: [
            ComposerFileAttachment(bytes: Uint8List(1), filename: "notes.pdf", source: ComposerAttachmentSource.picker),
          ],
          agent: null,
          agentModel: null,
          fastMode: false,
        ),
      );
      response.complete(ApiResponse.success(testSession(id: "session-1")));
      await pending;
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => productAnalyticsService.logEvent(
          event: any(named: "event", that: isA<PromptFilesSentEvent>()),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );

      service.retryFollowUp(promptId: "prm_a");
      await Future<void>.delayed(Duration.zero);

      expect(sentPromptIds, ["prm_a", "prm_a"]);
      verifyInOrder([
        () => productAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.sessionMessageSent(
            submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
        () => productAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.promptFilesSent(
            fileCount: AnalyticsFileCountBucket.one,
            source: AnalyticsFileSource.picker,
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ]);
    });

    test("a dictated follow-up reaches the bridge marked", () async {
      final pending = launch();
      service.addFollowUp(
        launchId: "launch-1",
        submission: const QueuedSessionSubmission.text(
          promptId: "prm_a",
          text: "and then this",
          inputMode: ComposerInputMode.voiceAssisted,
          attachments: [],
          agent: null,
          agentModel: null,
          fastMode: false,
        ),
      );
      response.complete(ApiResponse.success(testSession(id: "session-1")));
      await pending;
      await Future<void>.delayed(Duration.zero);

      verify(
        () => sessionRepository.sendMessage(
          sessionId: "session-1",
          promptId: "prm_a",
          text: wrapDictatedText(text: "and then this"),
          attachments: const [],
          agent: null,
          model: null,
          variant: null,
          fastMode: false,
          command: null,
        ),
      ).called(1);
    });

    test("a failure is kept and logged with the original error, holds the rest, and retries unchanged", () async {
      final records = <LogRecord>[];
      setLogSink(sink: _RecordingSink(records: records));
      addTearDown(() => setLogSink(sink: const StdoutLogSink()));
      sendResponses.add(ApiResponse.error(ApiError.generic()));

      await launchWithFollowUps();

      expect(sentPromptIds, ["prm_a"]);
      expect(storage.read(launchId: "launch-1")?.followUps.first, isA<FailedLaunchFollowUp>());
      expect(records.single.message, "Failed to send follow-up prm_a of launch launch-1 to session session-1");
      expect(records.single.diagnosticError, isNotNull);
      expect(feedbackPromptService.failedSessions, ["session-1"]);

      service.retryFollowUp(promptId: "prm_a");
      await Future<void>.delayed(Duration.zero);

      expect(sentPromptIds, ["prm_a", "prm_a", "prm_b"]);
      expect(storage.readAll(), isEmpty);
    });

    test("cancelling a failed follow-up lets the next one go", () async {
      sendResponses.add(ApiResponse.error(ApiError.generic()));
      await launchWithFollowUps();

      service.cancelFollowUp(promptId: "prm_a");
      await Future<void>.delayed(Duration.zero);

      expect(sentPromptIds, ["prm_a", "prm_b"]);
      expect(storage.readAll(), isEmpty);
    });

    test("a follow-up the bridge settled while its send was in flight neither fails nor holds the rest", () async {
      when(
        () => sessionRepository.sendMessage(
          sessionId: "session-1",
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
        ),
      ).thenAnswer((invocation) async {
        final promptId = invocation.namedArguments[#promptId] as String;
        sentPromptIds.add(promptId);
        if (promptId != "prm_a") return ApiResponse.success(null);
        // The bridge runs it and says so before the request itself errors.
        service.settleFollowUp(promptId: promptId);
        return ApiResponse.error(ApiError.generic());
      });

      await launchWithFollowUps();

      expect(sentPromptIds, ["prm_a", "prm_b"]);
      expect(storage.readAll(), isEmpty);
      expect(feedbackPromptService.failedSessions, isEmpty);
    });
  });
}

class _RecordingSink({required final List<LogRecord> records}) implements LogSink {
  @override
  void write({required LogRecord record}) => records.add(record);

  @override
  Future<void> flush() => Future<void>.value();
}
