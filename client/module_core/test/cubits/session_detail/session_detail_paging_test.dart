import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/load_through_outcome.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/cubits/session_detail/tool_output_fetch.dart";
import "package:sesori_dart_core/src/repositories/models/session_messages_through_result.dart";
import "package:sesori_dart_core/src/repositories/models/session_prompt_index_result.dart";
import "package:sesori_dart_core/src/repositories/models/tool_output_result.dart";
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
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
    registerFallbackValue(PermissionReply.once);
  });

  late MockSessionDetailLoadService loadService;
  late MockConnectionService connectionService;
  late MockSessionRepository sessionRepository;
  late StreamController<SesoriSessionEvent> sessionEvents;
  late SessionDetailCubit cubit;

  /// A loaded cubit showing the newest page, with older history available.
  Future<void> openSession({
    required List<MessageWithParts> messages,
    required int? olderMessagesCursor,
    required int? userMessagesBefore,
    required Future<SessionPromptIndexResult> Function() promptIndex,
  }) async {
    loadService = MockSessionDetailLoadService();
    connectionService = MockConnectionService();
    sessionRepository = MockSessionRepository();
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
    when(() => loadService.loadPromptIndex(sessionId: _sessionId)).thenAnswer((_) => promptIndex());
    when(
      () => loadService.load(
        session: any(named: "session"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer(
      (_) async => SessionDetailLoadResult.loaded(
        snapshot: _snapshot(
          messages: messages,
          olderMessagesCursor: olderMessagesCursor,
          userMessagesBefore: userMessagesBefore,
        ),
      ),
    );
    when(
      () => loadService.reload(
        session: any(named: "session"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer(
      (_) async => SessionDetailLoadResult.loaded(
        snapshot: _snapshot(
          messages: messages,
          olderMessagesCursor: olderMessagesCursor,
          userMessagesBefore: userMessagesBefore,
        ),
      ),
    );

    cubit = SessionDetailCubit(
      connectionService,
      claimProjectView: true,
      pluginManagementService: stubbedPluginManagementService(),
      interactionCalculator: const SessionInteractionCalculator(),
      loadService: loadService,
      sessionAbortService: SessionAbortService(repository: sessionRepository),
      autoContinuationService: SessionAutoContinuationService(repository: sessionRepository),
      approvalService: SessionApprovalService(repository: sessionRepository),
      promptDispatcher: sessionRepository,
      permissionRepository: MockPermissionRepository(),
      sessionViewingService: stubbedSessionViewingService(),
      projectViewingService: stubbedProjectViewingService(),
      lifecycleSource: FakeLifecycleSource(),
      composerDraftRepository: inMemoryComposerDraftRepository(),
      productAnalyticsService: stubbedProductAnalyticsService(),
      feedbackPromptService: FakeFeedbackPromptService(),
      sessionId: _sessionId,
      projectId: "project-1",
      notificationCanceller: MockNotificationCanceller(),
      failureReporter: MockFailureReporter(),
      bridgeSettingsService: stubbedBridgeSettingsService(),
      sseEventTracker: MockSseEventTracker(),
      sessionLaunchService: inMemorySessionLaunchService(launchRepository: inMemorySessionLaunchRepository()),
    );
    addTearDown(cubit.close);
    await _awaitLoaded(cubit);
  }

  group("session detail paging", () {
    setUp(() async {
      await openSession(
        messages: [
          _message(id: "m5"),
          _message(id: "m6"),
        ],
        olderMessagesCursor: 5,
        userMessagesBefore: 4,
        promptIndex: () async => const SessionPromptIndexUnsupported(),
      );
    });

    test("loading older messages prepends them and advances the cursor", () async {
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5, storedOnly: false)).thenAnswer(
        (_) async => (
          messages: [
            _message(id: "m3"),
            _message(id: "m4"),
          ],
          olderMessagesCursor: 3,
          userMessagesBefore: 2,
        ),
      );
      expect((cubit.state as SessionDetailLoaded).userMessagesBeforeOldest, 4);

      await cubit.loadOlderMessages();

      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages.map((message) => message.info.id), const ["m3", "m4", "m5", "m6"]);
      expect(state.olderMessagesCursor, 3);
      expect(state.userMessagesBeforeOldest, 2, reason: "the oldest page loaded sets the numbering base");
      expect(state.isLoadingOlderMessages, isFalse);
    });

    test("reaching the start of the transcript clears the cursor", () async {
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5, storedOnly: false)).thenAnswer(
        (_) async => (messages: [_message(id: "m4")], olderMessagesCursor: null, userMessagesBefore: 3),
      );

      await cubit.loadOlderMessages();

      final state = cubit.state as SessionDetailLoaded;
      expect(state.olderMessagesCursor, isNull, reason: "no cursor means no load-older affordance");
    });

    test("loading older messages is a no-op once the start is loaded", () async {
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5, storedOnly: false)).thenAnswer(
        (_) async => (messages: const <MessageWithParts>[], olderMessagesCursor: null, userMessagesBefore: 0),
      );
      await cubit.loadOlderMessages();

      await cubit.loadOlderMessages();

      verify(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5, storedOnly: false)).called(1);
    });

    test("a failed load keeps the cursor so the user can retry", () async {
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5, storedOnly: false))
          .thenAnswer((_) async => null);

      await cubit.loadOlderMessages();

      final state = cubit.state as SessionDetailLoaded;
      expect(state.olderMessagesCursor, 5, reason: "a failure is not the end of the transcript");
      expect(state.isLoadingOlderMessages, isFalse);
    });

    test("an older page never duplicates a message already shown", () async {
      // The bridge's cursor is exclusive, but a live event may have appended
      // the same message while the page was in flight.
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5, storedOnly: false)).thenAnswer(
        (_) async => (
          messages: [
            _message(id: "m4"),
            _message(id: "m5"),
          ],
          olderMessagesCursor: null,
          userMessagesBefore: 3,
        ),
      );

      await cubit.loadOlderMessages();

      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages.map((message) => message.info.id), const ["m4", "m5", "m6"]);
    });

    test("a page that lands after a refresh is dropped, not spliced in", () async {
      // The refresh replaces the transcript and resets the cursor, so this
      // page describes history that no longer joins onto what is shown.
      final pageCompleter = Completer<SessionMessagePage?>();
      when(
        () => loadService.loadOlderMessages(sessionId: _sessionId, before: 5, storedOnly: false),
      ).thenAnswer((_) => pageCompleter.future);

      final loading = cubit.loadOlderMessages();
      await cubit.reload();
      pageCompleter.complete((messages: [_message(id: "m4")], olderMessagesCursor: 4, userMessagesBefore: 3));
      await loading;

      final state = cubit.state as SessionDetailLoaded;
      expect(
        state.messages.map((message) => message.info.id),
        const ["m5", "m6"],
        reason: "splicing a stale page onto a refreshed transcript would leave a gap",
      );
      expect(state.olderMessagesCursor, 5, reason: "the refreshed cursor must survive");
      expect(state.userMessagesBeforeOldest, 4);
    });

    test("a reload returns to the newest page and drops paged-back history", () async {
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5, storedOnly: false)).thenAnswer(
        (_) async => (messages: [_message(id: "m4")], olderMessagesCursor: 4, userMessagesBefore: 3),
      );
      await cubit.loadOlderMessages();
      expect((cubit.state as SessionDetailLoaded).messages, hasLength(3));

      await cubit.reload();

      final state = cubit.state as SessionDetailLoaded;
      expect(
        state.messages.map((message) => message.info.id),
        const ["m5", "m6"],
        reason: "keeping older pages would leave a gap if the session moved on",
      );
      expect(state.olderMessagesCursor, 5);
      expect(state.userMessagesBeforeOldest, 4, reason: "the refreshed page is the oldest again");
    });

    test("an older bridge's page leaves the prompts unnumbered", () async {
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5, storedOnly: false)).thenAnswer(
        (_) async => (messages: [_message(id: "m4")], olderMessagesCursor: 4, userMessagesBefore: null),
      );

      await cubit.loadOlderMessages();

      expect((cubit.state as SessionDetailLoaded).userMessagesBeforeOldest, isNull);
    });
  });

  group("loading through a prompt", () {
    setUp(() async {
      await openSession(
        messages: [
          _message(id: "m5"),
          _message(id: "m6"),
        ],
        olderMessagesCursor: 5,
        userMessagesBefore: 4,
        promptIndex: () async => const SessionPromptIndexUnsupported(),
      );
    });

    void answerThrough({required Future<SessionMessagesThroughResult> Function() result}) {
      when(
        () => loadService.loadMessagesThrough(sessionId: _sessionId, throughSeq: 2, before: 5, storedOnly: false),
      ).thenAnswer((_) => result());
    }

    SessionMessagesThroughResult range({required int? nextCursor, required int userMessagesBefore}) =>
        SessionMessagesThroughAvailable(
          messages: [
            _message(id: "m2"),
            _message(id: "m3"),
            _message(id: "m4"),
          ],
          olderMessagesCursor: nextCursor,
          userMessagesBefore: userMessagesBefore,
        );

    test("prepends the whole range and takes its cursor and count", () async {
      answerThrough(result: () async => range(nextCursor: 2, userMessagesBefore: 1));

      final outcome = await cubit.loadMessagesThrough(messageId: "m2", seq: 2);

      final state = cubit.state as SessionDetailLoaded;
      expect(outcome, isA<LoadThroughLoaded>());
      expect(state.messages.map((message) => message.info.id), const ["m2", "m3", "m4", "m5", "m6"]);
      expect(state.olderMessagesCursor, 2);
      expect(state.userMessagesBeforeOldest, 1);
    });

    test("a loaded target needs no request", () async {
      final outcome = await cubit.loadMessagesThrough(messageId: "m5", seq: 5);

      expect(outcome, isA<LoadThroughLoaded>());
      verifyNever(
        () => loadService.loadMessagesThrough(
          sessionId: any(named: "sessionId"),
          throughSeq: any(named: "throughSeq"),
          before: any(named: "before"),
          storedOnly: any(named: "storedOnly"),
        ),
      );
    });

    test("a range without the target reports it missing but still prepends", () async {
      answerThrough(result: () async => range(nextCursor: 2, userMessagesBefore: 1));

      final outcome = await cubit.loadMessagesThrough(messageId: "gone", seq: 2);

      expect(outcome, isA<LoadThroughTargetMissing>());
      expect((cubit.state as SessionDetailLoaded).messages, hasLength(5));
    });

    test("a failure leaves the transcript as it was", () async {
      answerThrough(
        result: () async =>
            SessionMessagesThroughFailure(error: ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null)),
      );

      expect(await cubit.loadMessagesThrough(messageId: "m2", seq: 2), isA<LoadThroughFailed>());
      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages, hasLength(2));
      expect(state.olderMessagesCursor, 5);
    });

    test("a range that lands after a refresh is dropped", () async {
      final completer = Completer<SessionMessagesThroughResult>();
      answerThrough(result: () => completer.future);

      final loading = cubit.loadMessagesThrough(messageId: "m2", seq: 2);
      await cubit.reload();
      completer.complete(range(nextCursor: 2, userMessagesBefore: 1));

      expect(await loading, isA<LoadThroughSuperseded>());
      expect((cubit.state as SessionDetailLoaded).messages, hasLength(2));
    });

    test("a range asked for during a refresh is not sent", () async {
      // The refresh has bumped the generation but still shows the old
      // cursor, so a range read from it would splice onto the refreshed page.
      final metadata = Completer<SessionDetailMetadataLoadResult>();
      when(() => loadService.loadMetadata(sessionId: _sessionId)).thenAnswer((_) => metadata.future);

      connectionService.emitDataMayBeStale();
      await awaitState(
        cubit: cubit,
        predicate: (state) => state is SessionDetailLoaded && state.isRefreshing,
        description: "a refreshing transcript",
      );

      expect(await cubit.loadMessagesThrough(messageId: "m2", seq: 2), isA<LoadThroughSuperseded>());
      verifyNever(
        () => loadService.loadMessagesThrough(
          sessionId: any(named: "sessionId"),
          throughSeq: any(named: "throughSeq"),
          before: any(named: "before"),
          storedOnly: any(named: "storedOnly"),
        ),
      );
      metadata.complete(SessionDetailMetadataFailed(error: StateError("offline"), stackTrace: null));
      await pumpEventQueue();
    });

    test("an older page landing after a farther range keeps the farther cursor", () async {
      final page = Completer<SessionMessagePage?>();
      when(
        () => loadService.loadOlderMessages(sessionId: _sessionId, before: 5, storedOnly: false),
      ).thenAnswer((_) => page.future);
      answerThrough(result: () async => range(nextCursor: 2, userMessagesBefore: 1));

      final loadingOlder = cubit.loadOlderMessages();
      await cubit.loadMessagesThrough(messageId: "m2", seq: 2);
      page.complete((messages: [_message(id: "m4")], olderMessagesCursor: 4, userMessagesBefore: 3));
      await loadingOlder;

      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages.map((message) => message.info.id), const ["m2", "m3", "m4", "m5", "m6"]);
      expect(state.olderMessagesCursor, 2, reason: "the newer page's cursor would reload m2 to m3");
      expect(state.userMessagesBeforeOldest, 1, reason: "the count moves with its cursor");
      expect(state.isLoadingOlderMessages, isFalse);
    });
  });

  group("the prompt index", () {
    const first = [
      SessionPromptIndexEntry.opener(messageId: "m1", seq: 1, number: 1, createdAt: null, preview: "First"),
    ];
    const second = [
      SessionPromptIndexEntry.opener(messageId: "m2", seq: 2, number: 1, createdAt: null, preview: "Second"),
    ];

    test("arrives for a transcript with older history", () async {
      await openSession(
        messages: [_message(id: "m5")],
        olderMessagesCursor: 5,
        userMessagesBefore: 4,
        promptIndex: () async => const SessionPromptIndexAvailable(entries: first),
      );
      await pumpEventQueue();

      expect((cubit.state as SessionDetailLoaded).promptIndex, first);
    });

    test("is not asked for when the whole history is loaded", () async {
      await openSession(
        messages: [_message(id: "m5")],
        olderMessagesCursor: null,
        userMessagesBefore: 0,
        promptIndex: () async => const SessionPromptIndexAvailable(entries: first),
      );
      await pumpEventQueue();

      expect((cubit.state as SessionDetailLoaded).promptIndex, isNull);
      verifyNever(() => loadService.loadPromptIndex(sessionId: any(named: "sessionId")));
    });

    test("stays null when the fetch fails", () async {
      await openSession(
        messages: [_message(id: "m5")],
        olderMessagesCursor: 5,
        userMessagesBefore: 4,
        promptIndex: () async =>
            SessionPromptIndexFailure(error: ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null)),
      );
      await pumpEventQueue();

      expect((cubit.state as SessionDetailLoaded).promptIndex, isNull);
    });

    test("is refetched on a refresh, and an index that lands after it is dropped", () async {
      final stale = Completer<SessionPromptIndexResult>();
      final results = [stale.future, Future.value(const SessionPromptIndexAvailable(entries: second))];
      await openSession(
        messages: [_message(id: "m5")],
        olderMessagesCursor: 5,
        userMessagesBefore: 4,
        promptIndex: () => results.removeAt(0),
      );

      await cubit.reload();
      await pumpEventQueue();
      stale.complete(const SessionPromptIndexAvailable(entries: first));
      await pumpEventQueue();

      expect(
        (cubit.state as SessionDetailLoaded).promptIndex,
        second,
        reason: "the first index describes the transcript the refresh replaced",
      );
    });
  });

  group("summary tool output", () {
    const key = (messageId: "m5", partId: "p1");
    Map<ToolOutputKey, ToolOutputFetch> outputs() => (cubit.state as SessionDetailLoaded).toolOutputs;
    void stubFetch(Future<ToolOutputResult> Function(Invocation) result) => when(
      () => loadService.loadToolOutput(sessionId: _sessionId, messageId: "m5", partId: "p1"),
    ).thenAnswer(result);

    setUp(() async {
      await openSession(
        messages: [_message(id: "m5")],
        olderMessagesCursor: null,
        userMessagesBefore: 0,
        promptIndex: () async => const SessionPromptIndexUnsupported(),
      );
    });

    test("loads once, however often the row asks while it is on its way", () async {
      final pending = Completer<ToolOutputResult>();
      stubFetch((_) => pending.future);

      unawaited(cubit.fetchToolOutput(messageId: "m5", partId: "p1"));
      unawaited(cubit.fetchToolOutput(messageId: "m5", partId: "p1"));
      expect(outputs()[key], const ToolOutputLoading());
      pending.complete(const ToolOutputAvailable(output: "clean", error: null));
      await pumpEventQueue();

      expect(outputs()[key], const ToolOutputLoaded(output: "clean", error: null));
      verify(() => loadService.loadToolOutput(sessionId: _sessionId, messageId: "m5", partId: "p1")).called(1);
    });

    test("a failed fetch is marked, and the next ask tries again", () async {
      stubFetch(
        (_) async => ToolOutputFailure(error: ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
      );
      await cubit.fetchToolOutput(messageId: "m5", partId: "p1");
      expect(outputs()[key], const ToolOutputFailed());

      stubFetch((_) async => const ToolOutputAvailable(output: null, error: "exit 1"));
      await cubit.fetchToolOutput(messageId: "m5", partId: "p1");
      expect(outputs()[key], const ToolOutputLoaded(output: null, error: "exit 1"));
    });

    test("fetched output outlives a refresh, which brings the summaries back", () async {
      stubFetch((_) async => const ToolOutputAvailable(output: "clean", error: null));
      await cubit.fetchToolOutput(messageId: "m5", partId: "p1");
      when(
        () => loadService.loadMetadata(sessionId: _sessionId),
      ).thenAnswer((_) async => const SessionDetailMetadataLoadResult.found(session: testConstSession));

      connectionService.emitDataMayBeStale();
      await pumpEventQueue();

      verify(
        () => loadService.reload(
          session: any(named: "session"),
          projectId: any(named: "projectId"),
        ),
      ).called(1);
      expect(outputs()[key], const ToolOutputLoaded(output: "clean", error: null));
    });

    test("a tool that finished live keeps its output for a later summary", () async {
      const running = MessagePart.tool(
        id: "p1",
        sessionID: _sessionId,
        messageID: "m5",
        tool: "bash",
        state: ToolState(
          status: ToolStatus.running,
          title: null,
          output: "partial",
          error: null,
          shellCommand: "make",
          attachments: [],
        ),
      );
      sessionEvents.add(const SesoriMessagePartUpdated(part: running));
      await pumpEventQueue();
      expect(outputs()[key], isNull, reason: "a running tool's output is not final");

      sessionEvents.add(
        const SesoriMessagePartUpdated(
          part: MessagePart.tool(
            id: "p1",
            sessionID: _sessionId,
            messageID: "m5",
            tool: "bash",
            state: ToolState(
              status: ToolStatus.completed,
              title: null,
              output: "done",
              error: null,
              shellCommand: "make",
              attachments: [],
            ),
          ),
        ),
      );
      await pumpEventQueue();

      expect(outputs()[key], const ToolOutputLoaded(output: "done", error: null));
      unawaited(cubit.fetchToolOutput(messageId: "m5", partId: "p1"));
      verifyNever(
        () => loadService.loadToolOutput(
          sessionId: any(named: "sessionId"),
          messageId: any(named: "messageId"),
          partId: any(named: "partId"),
        ),
      );
    });
  });
}

Future<void> _awaitLoaded(SessionDetailCubit cubit) async {
  await awaitState(
    cubit: cubit,
    predicate: (state) => state is SessionDetailLoaded,
    description: "SessionDetailLoaded",
  );
}

MessageWithParts _message({required String id}) => MessageWithParts(
  info: Message.user(
    promptId: null,
    id: id,
    sessionID: _sessionId,
    agent: null,
    time: const MessageTime(created: 1, completed: null),
  ),
  parts: const [],
);

SessionDetailSnapshot _snapshot({
  required List<MessageWithParts> messages,
  required int? olderMessagesCursor,
  required int? userMessagesBefore,
}) => SessionDetailSnapshot(
  areOptionsStale: false,
  bridgeQueuedPrompts: const [],
  projectId: "project-1",
  pluginId: "plugin-1",
  supportsPromptAttachments: true,
  messages: messages,
  olderMessagesCursor: olderMessagesCursor,
  userMessagesBefore: userMessagesBefore,
  awaitingHarnessSync: false,
  pendingQuestions: const [],
  pendingPermissions: const [],
  childSessions: const [],
  statuses: const {},
  agents: const [],
  providerData: null,
  commands: const [],
  canonicalSessionTitle: null,
  promptDefaults: null,
  isRootSession: true,
  isArchived: false,
  cannotContinueMessage: null,
);
