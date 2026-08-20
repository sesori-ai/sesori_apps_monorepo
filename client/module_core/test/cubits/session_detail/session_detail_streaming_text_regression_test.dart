import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/platform/notification_canceller.dart";
import "package:sesori_dart_core/src/repositories/permission_repository.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class MockNotificationCanceller() extends Mock implements NotificationCanceller;

class MockPermissionRepository() extends Mock implements PermissionRepository;

class MockSessionDetailLoadService() extends Mock implements SessionDetailLoadService;

const _sessionId = "hermes-session-1";

/// Builds the client event stream for a realistic Hermes multi-tool turn where
/// the assistant response is split into several text segments interleaved with
/// tool calls — the shape that reproduced "response text disappears with
/// multiple tool calls". Each text segment is:
///   message envelope -> empty part -> streamed deltas
/// and (for the happy path) a finalize snapshot with the complete text.
List<SesoriSessionEvent> buildMultiToolTurn({required bool includeFinalize}) {
  final events = <SesoriSessionEvent>[];
  const segments = [
    ("m0", "I'll inspect the repo."),
    ("m1", "Found the files."),
    ("m2", "Here is the summary."),
  ];
  const toolIds = ["t0", "t1"];

  var index = 0;
  for (final (messageId, text) in segments) {
    events.add(SesoriMessageUpdated(
      info: Message.assistant(
        id: messageId,
        sessionID: _sessionId,
        agent: "hermes",
        modelID: "deepseek-v4-flash",
        providerID: "hermes",
        time: null,
      ),
    ));
    final part = MessagePart(
      id: "$messageId-text",
      sessionID: _sessionId,
      messageID: messageId,
      type: MessagePartType.text,
      text: "",
      tool: null,
      state: null,
      prompt: null,
      description: null,
      agent: null,
      agentName: null,
      attempt: null,
      retryError: null,
      attachment: null,
    );
    events.add(SesoriMessagePartUpdated(part: part));
    // stream the text as small deltas
    for (final chunk in text.split(" ")) {
      events.add(SesoriMessagePartDelta(
        sessionID: _sessionId,
        messageID: messageId,
        partID: part.id,
        field: "text",
        delta: "$chunk ",
      ));
    }
    if (includeFinalize) {
      events.add(SesoriMessagePartUpdated(part: part.copyWith(text: "$text ")));
    }
    // tools between the segments (the last segment gets none)
    if (index < toolIds.length && index < segments.length - 1) {
      final toolId = toolIds[index];
      events.add(SesoriMessageUpdated(
        info: Message.assistant(
          id: toolId,
          sessionID: _sessionId,
          agent: "hermes",
          modelID: "deepseek-v4-flash",
          providerID: "hermes",
          time: null,
        ),
      ));
      events.add(SesoriMessagePartUpdated(
        part: MessagePart(
          id: "$toolId-call",
          sessionID: _sessionId,
          messageID: toolId,
          type: MessagePartType.tool,
          text: null,
          tool: "read",
          state: const ToolState(
            status: ToolStatus.completed,
            title: "read",
            output: "ok",
            error: null,
            attachments: [],
          ),
          prompt: null,
          description: null,
          agent: null,
          agentName: null,
          attempt: null,
          retryError: null,
          attachment: null,
        ),
      ));
    }
    index++;
  }
  return events;
}

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

  group("SessionDetailCubit streaming text survives multi-tool turns", () {
    late MockSessionRepository mockSessionRepository;
    late MockConnectionService mockConnectionService;
    late MockNotificationCanceller mockNotificationCanceller;
    late MockPermissionRepository mockPermissionRepository;
    late StreamController<SesoriSessionEvent> sessionEvents;

    setUp(() {
      mockSessionRepository = MockSessionRepository();
      mockConnectionService = MockConnectionService();
      mockNotificationCanceller = MockNotificationCanceller();
      mockPermissionRepository = MockPermissionRepository();
      sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
      final globalEvents = StreamController<SseEvent>.broadcast();
      final connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(connectedStatus);
      addTearDown(() async {
        await sessionEvents.close();
        await globalEvents.close();
        await connectionStatus.close();
      });

      when(() => mockConnectionService.sessionEvents(_sessionId)).thenAnswer((_) => sessionEvents.stream);
      when(() => mockConnectionService.events).thenAnswer((_) => globalEvents.stream);
      when(() => mockConnectionService.status).thenAnswer((_) => connectionStatus);
      when(() => mockConnectionService.currentStatus).thenAnswer((_) => connectionStatus.value);
      when(
        () => mockNotificationCanceller.cancelForSession(sessionId: any(named: "sessionId")),
      ).thenReturn(null);
      when(
        () => mockPermissionRepository.replyToPermission(
          requestId: any(named: "requestId"),
          sessionId: any(named: "sessionId"),
          reply: any(named: "reply"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
    });

    SessionDetailCubit createCubit() {
      final mockLoadService = MockSessionDetailLoadService();
      when(
        () => mockLoadService.load(
          sessionId: any(named: "sessionId"),
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer(
        (_) async => const SessionDetailLoadResult.loaded(
          snapshot: SessionDetailSnapshot(
            bridgeQueuedPrompts: [],
            projectId: "project-1",
            pluginId: "hermes",
            supportsPromptAttachments: false,
            messages: [],
            olderMessagesCursor: null,
            pendingQuestions: [],
            pendingPermissions: [],
            childSessions: [],
            statuses: {},
            agents: [],
            providerData: null,
            commands: [],
            canonicalSessionTitle: null,
            promptDefaults: null,
            isRootSession: true,
            isArchived: false,
          ),
          isBridgeConnected: true,
        ),
      );
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: mockLoadService,
        promptDispatcher: mockSessionRepository,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        sessionId: _sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);
      return cubit;
    }

    Future<void> awaitLoaded(SessionDetailCubit cubit) async {
      for (var i = 0; i < 200; i++) {
        if (cubit.state is SessionDetailLoaded) return;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      fail("timeout waiting loaded; state=${cubit.state}");
    }

    String committedText(SessionDetailCubit cubit) {
      final state = cubit.state as SessionDetailLoaded;
      return state.messages
          .expand((m) => m.parts)
          .where((p) => p.type == MessagePartType.text && p.text != null)
          .map((p) => p.text!)
          .join("|");
    }

    test("streamed text is committed even when end-of-turn finalize snapshots are lost", () async {
      // This is the regression: the deltas feed only the transient streaming
      // buffer. If the finalize snapshot (the bridge's only commit) is lost
      // (disconnect/reconnect mid-turn), the committed parts used to stay
      // empty and the response text "disappeared". Deltas must commit into the
      // parts directly so the text survives.
      final cubit = createCubit();
      await awaitLoaded(cubit);
      for (final e in buildMultiToolTurn(includeFinalize: false)) {
        sessionEvents.add(e);
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final text = committedText(cubit);
      expect(text, contains("I'll inspect the repo."));
      expect(text, contains("Here is the summary."));
    });

    test("happy path with finalize snapshots still yields the full text exactly once", () async {
      final cubit = createCubit();
      await awaitLoaded(cubit);
      for (final e in buildMultiToolTurn(includeFinalize: true)) {
        sessionEvents.add(e);
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final text = committedText(cubit);
      // No doubling from the delta-append + finalize-replace: each segment's
      // text appears exactly once.
      expect("I'll inspect the repo.".allMatches(text).length, 1);
      expect(text, contains("Found the files."));
      expect(text, contains("Here is the summary."));
    });
  });
}
