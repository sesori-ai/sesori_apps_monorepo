import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

const _sessionId = "session-1";

void main() {
  const connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
    registerFallbackValue(PermissionReply.once);
  });

  late MockSessionDetailLoadService loadService;
  late MockConnectionService connectionService;
  late MockSessionRepository sessionRepository;
  late SessionDetailCubit cubit;

  /// A loaded cubit showing the newest page, with older history available.
  Future<void> openSession({
    required List<MessageWithParts> messages,
    required int? olderMessagesCursor,
  }) async {
    loadService = MockSessionDetailLoadService();
    connectionService = MockConnectionService();
    sessionRepository = MockSessionRepository();
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
      () => loadService.load(
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer(
      (_) async => SessionDetailLoadResult.loaded(
        snapshot: _snapshot(messages: messages, olderMessagesCursor: olderMessagesCursor),
        isBridgeConnected: true,
      ),
    );
    when(
      () => loadService.reload(
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer(
      (_) async => SessionDetailLoadResult.loaded(
        snapshot: _snapshot(messages: messages, olderMessagesCursor: olderMessagesCursor),
        isBridgeConnected: true,
      ),
    );

    cubit = SessionDetailCubit(
      connectionService,
      loadService: loadService,
      promptDispatcher: sessionRepository,
      permissionRepository: MockPermissionRepository(),
      sessionViewingService: stubbedSessionViewingService(),
      projectViewingService: stubbedProjectViewingService(),
      lifecycleSource: FakeLifecycleSource(),
      composerDraftRepository: inMemoryComposerDraftRepository(),
      productAnalyticsService: stubbedProductAnalyticsService(),
      sessionId: _sessionId,
      projectId: "project-1",
      notificationCanceller: MockNotificationCanceller(),
      failureReporter: MockFailureReporter(),
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
      );
    });

    test("loading older messages prepends them and advances the cursor", () async {
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5)).thenAnswer(
        (_) async => (
          messages: [
            _message(id: "m3"),
            _message(id: "m4"),
          ],
          olderMessagesCursor: 3,
        ),
      );

      await cubit.loadOlderMessages();

      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages.map((message) => message.info.id), const ["m3", "m4", "m5", "m6"]);
      expect(state.olderMessagesCursor, 3);
      expect(state.isLoadingOlderMessages, isFalse);
    });

    test("reaching the start of the transcript clears the cursor", () async {
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5)).thenAnswer(
        (_) async => (messages: [_message(id: "m4")], olderMessagesCursor: null),
      );

      await cubit.loadOlderMessages();

      final state = cubit.state as SessionDetailLoaded;
      expect(state.olderMessagesCursor, isNull, reason: "no cursor means no load-older affordance");
    });

    test("loading older messages is a no-op once the start is loaded", () async {
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5)).thenAnswer(
        (_) async => (messages: const <MessageWithParts>[], olderMessagesCursor: null),
      );
      await cubit.loadOlderMessages();

      await cubit.loadOlderMessages();

      verify(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5)).called(1);
    });

    test("a failed load keeps the cursor so the user can retry", () async {
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5)).thenAnswer((_) async => null);

      await cubit.loadOlderMessages();

      final state = cubit.state as SessionDetailLoaded;
      expect(state.olderMessagesCursor, 5, reason: "a failure is not the end of the transcript");
      expect(state.isLoadingOlderMessages, isFalse);
    });

    test("an older page never duplicates a message already shown", () async {
      // The bridge's cursor is exclusive, but a live event may have appended
      // the same message while the page was in flight.
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5)).thenAnswer(
        (_) async => (
          messages: [
            _message(id: "m4"),
            _message(id: "m5"),
          ],
          olderMessagesCursor: null,
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
        () => loadService.loadOlderMessages(sessionId: _sessionId, before: 5),
      ).thenAnswer((_) => pageCompleter.future);

      final loading = cubit.loadOlderMessages();
      await cubit.reload();
      pageCompleter.complete((messages: [_message(id: "m4")], olderMessagesCursor: 4));
      await loading;

      final state = cubit.state as SessionDetailLoaded;
      expect(
        state.messages.map((message) => message.info.id),
        const ["m5", "m6"],
        reason: "splicing a stale page onto a refreshed transcript would leave a gap",
      );
      expect(state.olderMessagesCursor, 5, reason: "the refreshed cursor must survive");
    });

    test("a reload returns to the newest page and drops paged-back history", () async {
      when(() => loadService.loadOlderMessages(sessionId: _sessionId, before: 5)).thenAnswer(
        (_) async => (messages: [_message(id: "m4")], olderMessagesCursor: 4),
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
    });
  });
}

Future<void> _awaitLoaded(SessionDetailCubit cubit) async {
  if (cubit.state is SessionDetailLoaded) return;
  await cubit.stream
      .firstWhere((state) => state is SessionDetailLoaded)
      .timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError("cubit never reached loaded; last state: ${cubit.state}"),
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
}) => SessionDetailSnapshot(
  bridgeQueuedPrompts: const [],
  projectId: "project-1",
  pluginId: "plugin-1",
  supportsPromptAttachments: true,
  messages: messages,
  olderMessagesCursor: olderMessagesCursor,
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
);
