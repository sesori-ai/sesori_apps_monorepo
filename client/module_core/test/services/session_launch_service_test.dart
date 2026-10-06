import "dart:async";

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
    service = SessionLaunchService(
      sessionRepository: sessionRepository,
      launchRepository: launchRepository,
      feedbackPromptService: feedbackPromptService,
      productAnalyticsService: productAnalyticsService,
      selectionTracker: selectionTracker,
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

  Future<void> launch() => service.launch(
    launchId: "launch-1",
    projectId: "project-1",
    pluginId: "plugin-1",
    startedAt: DateTime.utc(2026, 9, 27),
    submission: submission,
    agent: null,
    model: null,
    variant: null,
    fastMode: false,
    dedicatedWorktree: false,
  );

  test("a launch whose composer left mid-create still finishes everything it owes", () async {
    selectionTracker.recordAgent(projectId: "project-1", pluginId: "plugin-1", agentName: "build");
    final pending = launch();
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
    expect(selectionTracker.read(projectId: "project-1", pluginId: "plugin-1"), isNull);
    expect(feedbackPromptService.positiveInteractions, 1);
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

  test("success keeps a selection the user changed while the session was being created", () async {
    selectionTracker.recordAgent(projectId: "project-1", pluginId: "plugin-1", agentName: "build");
    final pending = launch();
    selectionTracker.recordAgent(projectId: "project-1", pluginId: "plugin-1", agentName: "plan");

    response.complete(ApiResponse.success(testSession(id: "session-1")));
    await pending;

    expect(selectionTracker.read(projectId: "project-1", pluginId: "plugin-1")?.agentName, "plan");
  });

  test("a failed create publishes its reason, reports it and logs the original error", () async {
    final records = <LogRecord>[];
    setLogSink(sink: _RecordingSink(records: records));
    addTearDown(() => setLogSink(sink: const StdoutLogSink()));
    selectionTracker.recordAgent(projectId: "project-1", pluginId: "plugin-1", agentName: "build");
    final pending = launch();

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
    expect(feedbackPromptService.failures, 1);
    verify(
      () => productAnalyticsService.logEvent(
        event: const ProductAnalyticsEvent.sessionCreationFailed(
          failureReason: AnalyticsSessionCreationFailureReason.unknown,
          workspaceKind: AnalyticsWorkspaceKind.project,
        ),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).called(1);
    expect(selectionTracker.read(projectId: "project-1", pluginId: "plugin-1"), isNotNull);
    expect(storage.readAll(), isEmpty);
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
      expect(feedbackPromptService.positiveInteractions, 3);
      verify(
        () => productAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.sessionMessageSent(
            submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).called(2);
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
      expect(feedbackPromptService.failures, 1);

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
      expect(feedbackPromptService.failures, 0);
    });
  });
}

class _RecordingSink({required final List<LogRecord> records}) implements LogSink {
  @override
  void write({required LogRecord record}) => records.add(record);

  @override
  Future<void> flush() => Future<void>.value();
}
