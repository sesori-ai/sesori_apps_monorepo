import "dart:async";

import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:mocktail/mocktail.dart";
import "package:record/record.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart"
    show
        AnalyticsDeliveryResult,
        AppRouteDef,
        OnboardingSurface,
        ProductAnalyticsEvent,
        ProductAnalyticsService,
        ProductAnalyticsState,
        ProjectViewClaim,
        ProjectViewPaneClaim,
        ProjectViewingService,
        RouteSource,
        SessionListItemState,
        SessionOptionsCatalog,
        SessionOptionsRepositoryAvailable,
        SessionOptionsRepositoryFailure,
        SessionOptionsRequestMode,
        latestUserActivityAt;
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/project_api.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/api/storage/composer_draft_storage.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/capabilities/relay/room_key_storage.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/capabilities/session/session_service.dart";
import "package:sesori_dart_core/src/capabilities/voice/voice_api.dart";
import "package:sesori_dart_core/src/cubits/chat_input_mode/chat_input_mode_cubit.dart";
import "package:sesori_dart_core/src/cubits/connection_overlay/connection_overlay_cubit.dart";
import "package:sesori_dart_core/src/cubits/connection_overlay/connection_overlay_state.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_attachment.dart";
import "package:sesori_dart_core/src/platform/deep_link_source.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/platform/notification_canceller.dart";
import "package:sesori_dart_core/src/platform/url_launcher.dart";
import "package:sesori_dart_core/src/repositories/bridge_repository.dart";
import "package:sesori_dart_core/src/repositories/chat_input_mode_store.dart";
import "package:sesori_dart_core/src/repositories/composer_draft_repository.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/models/session_activity_info.dart";
import "package:sesori_dart_core/src/services/project_list_service.dart";
import "package:sesori_dart_core/src/services/registered_bridges_service.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_dart_core/src/services/session_list_service.dart";
import "package:sesori_dart_core/src/services/session_unseen_tracker.dart";
import "package:sesori_dart_core/src/services/session_viewing_service.dart";
import "package:sesori_dart_core/src/services/sse_event_tracker.dart";

import "package:sesori_mobile/capabilities/voice/audio_format_config.dart";
import "package:sesori_mobile/capabilities/voice/recorder_prewarm_client.dart";
import "package:sesori_mobile/capabilities/voice/recording_file_provider.dart";
import "package:sesori_mobile/capabilities/voice/wake_lock_service.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_shared/sesori_shared.dart";

// ---------------------------------------------------------------------------
// Mock classes
// ---------------------------------------------------------------------------

/// A fixed-state [ConnectionOverlayCubit] stand-in for widget tests.
///
/// Screens read the cubit through `ConnectionBanner.maybeFor` to decide
/// whether the top-nav connection banner shows, so any harness that pumps a
/// screen must provide one. Defaults to a connected [ConnectionOverlayHidden]
/// (no banner, chain up); pass e.g. `ConnectionOverlayState.bridgeOffline()`
/// to exercise the banner.
class StubConnectionOverlayCubit({
  ConnectionOverlayState initialState = const ConnectionOverlayState.hidden(connected: true),
}) extends Cubit<ConnectionOverlayState> implements ConnectionOverlayCubit {
  this : super(initialState);

  @override
  void reconnect() {}
}

/// The composer resolves its resting layout (hold-to-talk vs tap-to-type)
/// from [ChatInputModeCubit], so any harness that pumps a composer-bearing
/// screen must provide one. Defaults to the app default, voice-first.
class StubChatInputModeCubit({ChatInputMode initialState = ChatInputMode.voiceFirst})
    extends Cubit<ChatInputMode>
    implements ChatInputModeCubit {
  this : super(initialState);

  @override
  Future<void> select({required ChatInputMode mode}) async => emit(mode);
}

class MockProjectApi() extends Mock implements ProjectApi;

class MockProjectRepository() extends Mock implements ProjectRepository;

class MockBridgeRepository() extends Mock implements BridgeRepository;

class MockRegisteredBridgesService() extends Mock implements RegisteredBridgesService;

class MockSessionApi() extends Mock implements SessionApi;

class MockSessionService() extends Mock implements SessionService;

class MockSessionRepository() extends Mock implements SessionRepository;

class MockConnectionService() extends Mock implements ConnectionService {
  final StreamController<void> _dataMayBeStale = StreamController<void>.broadcast();

  @override
  Stream<void> get dataMayBeStale => _dataMayBeStale.stream;

  void emitDataMayBeStale() => _dataMayBeStale.add(null);
}

class MockOAuthFlowProvider() extends Mock implements OAuthFlowProvider;

class MockAuthSession() extends Mock implements AuthSession;

class MockAuthTokenProvider() extends Mock implements AuthTokenProvider;

class MockAuthenticatedHttpApiClient() extends Mock implements AuthenticatedHttpApiClient;

class MockRelayHttpApiClient() extends Mock implements RelayHttpApiClient;

class MockHttpApiClient() extends Mock implements HttpApiClient;

class MockRelayCryptoService() extends Mock implements RelayCryptoService;

class MockRoomKeyStorage() extends Mock implements RoomKeyStorage;

class MockRelayClient() extends Mock implements RelayClient;

class MockVoiceApi() extends Mock implements VoiceApi;

class MockAudioRecorder() extends Mock implements AudioRecorder;

class MockRecorderPrewarmClient() extends Mock implements RecorderPrewarmClient;

class MockRecordingFileProvider() extends Mock implements RecordingFileProvider;

class MockWakeLockService() extends Mock implements WakeLockService;

class MockAudioFormatConfig() extends Mock implements AudioFormatConfig;

class MockDeepLinkSource() extends Mock implements DeepLinkSource;

class MockFlutterSecureStorage() extends Mock implements FlutterSecureStorage;

class MockSecureStorage() extends Mock implements SecureStorage;

class MockLifecycleSource() extends Mock implements LifecycleSource {
  final BehaviorSubject<LifecycleState> _state = BehaviorSubject.seeded(LifecycleState.resumed);

  @override
  ValueStream<LifecycleState> get lifecycleStateStream => _state.stream;

  void emitState(LifecycleState state) => _state.add(state);
}

class MockNotificationCanceller() extends Mock implements NotificationCanceller;

class MockUrlLauncher() extends Mock implements UrlLauncher;

class MockProductAnalyticsService() extends Mock implements ProductAnalyticsService;

void stubProductAnalyticsService({required MockProductAnalyticsService service}) {
  final states = BehaviorSubject<ProductAnalyticsState>.seeded(ProductAnalyticsState.initial);
  addTearDown(states.close);
  when(
    () => service.logEvent(
      event: any(named: "event"),
      occurredAtUtc: any(named: "occurredAtUtc"),
    ),
  ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
  when(() => service.state).thenAnswer((_) => states.value);
  when(() => service.stateStream).thenAnswer((_) => states.stream);
}

ComposerDraftRepository inMemoryComposerDraftRepository() => ComposerDraftRepository(storage: ComposerDraftStorage());

void registerListServices({
  required MockProjectRepository projectRepository,
}) {
  _registerListServices(projectRepository: projectRepository, productAnalyticsService: null);
}

void registerListServicesWithProductAnalytics({
  required MockProjectRepository projectRepository,
  required MockProductAnalyticsService productAnalyticsService,
}) {
  _registerListServices(
    projectRepository: projectRepository,
    productAnalyticsService: productAnalyticsService,
  );
}

void _registerListServices({
  required MockProjectRepository projectRepository,
  required MockProductAnalyticsService? productAnalyticsService,
}) {
  if (getIt.isRegistered<ProjectListService>()) {
    getIt.unregister<ProjectListService>();
  }
  if (getIt.isRegistered<SessionListService>()) {
    getIt.unregister<SessionListService>();
  }
  if (getIt.isRegistered<ProductAnalyticsService>()) {
    getIt.unregister<ProductAnalyticsService>();
  }
  final analyticsService = productAnalyticsService ?? MockProductAnalyticsService();
  stubProductAnalyticsService(service: analyticsService);
  getIt.registerSingleton<ProjectListService>(
    ProjectListService(
      repository: projectRepository,
      activityCalculator: const SessionActivityCalculator(),
    ),
  );
  getIt.registerSingleton<SessionListService>(
    SessionListService(
      repository: projectRepository,
      activityCalculator: const SessionActivityCalculator(),
    ),
  );
  getIt.registerSingleton<ProductAnalyticsService>(analyticsService);
}

/// In-memory [SessionUnseenTracker] stand-in mirroring its lean contract:
/// overwrite-only maps plus a tick guard.
class FakeSessionUnseenTracker() extends Mock implements SessionUnseenTracker {
  final BehaviorSubject<Map<String, bool>> _projectUnseen = BehaviorSubject.seeded(const {});
  final BehaviorSubject<Map<String, Map<String, SessionListItemState>>> _sessionUnseen = BehaviorSubject.seeded(
    const {},
  );

  @override
  ValueStream<Map<String, bool>> get projectUnseen => _projectUnseen.stream;

  @override
  Map<String, bool> get currentProjectUnseen => _projectUnseen.value;

  @override
  ValueStream<Map<String, Map<String, SessionListItemState>>> get sessionUnseen => _sessionUnseen.stream;

  @override
  Map<String, Map<String, SessionListItemState>> get currentSessionUnseen => _sessionUnseen.value;

  int _tick = 0;
  final Map<String, int> _projectTick = {};

  @override
  int get tick => _tick;

  @override
  void seedProjects(Map<String, bool> unseenByProjectId, {required int sinceTick}) {
    _projectUnseen.add({..._projectUnseen.value, ...unseenByProjectId});
  }

  @override
  void seedSessions({
    required String projectId,
    required Map<String, SessionListItemState> stateBySessionId,
    required int sinceTick,
  }) {
    if ((_projectTick[projectId] ?? 0) > sinceTick) return;
    final sessions = Map<String, Map<String, SessionListItemState>>.from(_sessionUnseen.value);
    final current = sessions[projectId] ?? const <String, SessionListItemState>{};
    sessions[projectId] = {
      for (final entry in stateBySessionId.entries)
        entry.key: (
          unseen: entry.value.unseen,
          lastUserActivityAt: latestUserActivityAt(
            first: current[entry.key]?.lastUserActivityAt,
            second: entry.value.lastUserActivityAt,
          ),
        ),
    };
    _sessionUnseen.add(sessions);
  }

  @override
  void applyLocalSessionUnseen({
    required String projectId,
    required String sessionId,
    required bool unseen,
  }) {
    _projectTick[projectId] = ++_tick;
    final sessions = Map<String, Map<String, SessionListItemState>>.from(_sessionUnseen.value);
    final projectSessions = Map<String, SessionListItemState>.from(sessions[projectId] ?? const {});
    projectSessions[sessionId] = (
      unseen: unseen,
      lastUserActivityAt: projectSessions[sessionId]?.lastUserActivityAt,
    );
    sessions[projectId] = projectSessions;
    _sessionUnseen.add(sessions);
  }

  void emitProjectUnseen(Map<String, bool> unseen) => _projectUnseen.add(unseen);

  void emitSessionUnseen(Map<String, Map<String, SessionListItemState>> unseen) {
    for (final projectId in unseen.keys) {
      _projectTick[projectId] = ++_tick;
    }
    _sessionUnseen.add(unseen);
  }
}

class MockSessionViewingService() extends Mock implements SessionViewingService;

/// A [MockSessionViewingService] with its void methods pre-stubbed.
MockSessionViewingService stubbedSessionViewingService() {
  final mock = MockSessionViewingService();
  when(() => mock.setViewingSession(any())).thenReturn(null);
  when(() => mock.clearViewingSession(any())).thenReturn(null);
  return mock;
}

class MockProjectViewingService() extends Mock implements ProjectViewingService;

MockProjectViewingService stubbedProjectViewingService() {
  final mock = MockProjectViewingService();
  when(
    () => mock.beginListClaim(projectId: any(named: "projectId")),
  ).thenAnswer((_) => ProjectViewClaim());
  when(
    () => mock.beginDetailClaim(projectId: any(named: "projectId")),
  ).thenAnswer((_) => ProjectViewClaim());
  when(mock.beginWideListPaneClaim).thenAnswer((_) => ProjectViewPaneClaim());
  when(
    () => mock.markClaimReady(
      claim: any(named: "claim"),
      projectId: any(named: "projectId"),
    ),
  ).thenReturn(null);
  when(() => mock.markClaimFailed(claim: any(named: "claim"))).thenReturn(null);
  when(() => mock.releaseClaim(claim: any(named: "claim"))).thenReturn(null);
  when(
    () => mock.setWideListPaneVisible(
      claim: any(named: "claim"),
      isVisible: any(named: "isVisible"),
    ),
  ).thenReturn(null);
  when(
    () => mock.releaseWideListPaneClaim(claim: any(named: "claim")),
  ).thenReturn(null);
  when(mock.onDispose).thenAnswer((_) async {});
  return mock;
}

class MockRouteSource({AppRouteDef? initialRoute, @override var String? currentLocation})
    extends Mock
    implements RouteSource {
  final BehaviorSubject<AppRouteDef?> _currentRoute = BehaviorSubject.seeded(initialRoute);

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => _currentRoute.stream;

  AppRouteDef? get currentRoute => _currentRoute.value;

  void emitRoute(AppRouteDef? route) => _currentRoute.add(route);
}

class MockSseEventTracker() extends Mock implements SseEventTracker {
  final BehaviorSubject<Map<String, int>> _projectActivity = BehaviorSubject.seeded(const {});
  final BehaviorSubject<Map<String, Map<String, SessionActivityInfo>>> _sessionActivity = BehaviorSubject.seeded(
    const {},
  );
  final BehaviorSubject<Map<String, int>> _projectTimestampUpdates = BehaviorSubject.seeded(const {});

  @override
  ValueStream<Map<String, int>> get projectActivity => _projectActivity.stream;

  @override
  Map<String, int> get currentProjectActivity => _projectActivity.value;

  @override
  ValueStream<Map<String, Map<String, SessionActivityInfo>>> get sessionActivity => _sessionActivity.stream;

  @override
  Map<String, Map<String, SessionActivityInfo>> get currentSessionActivity => _sessionActivity.value;

  @override
  ValueStream<Map<String, int>> get projectTimestampUpdates => _projectTimestampUpdates.stream;

  @override
  Map<String, int> get currentProjectTimestampUpdates => _projectTimestampUpdates.value;

  void emitProjectActivity(Map<String, int> activity) => _projectActivity.add(activity);

  void emitSessionActivity(Map<String, Map<String, SessionActivityInfo>> activity) => _sessionActivity.add(activity);

  void emitProjectTimestampUpdate(Map<String, int> update) => _projectTimestampUpdates.add(update);

  @override
  Future<void> onDispose() async {
    await Future.wait([
      _projectActivity.close(),
      _sessionActivity.close(),
      _projectTimestampUpdates.close(),
    ]);
  }
}

class MockFailureReporter() extends Mock implements FailureReporter;

class MockFirebaseCrashlytics() extends Mock implements FirebaseCrashlytics;

class MockFirebaseAnalytics() extends Mock implements FirebaseAnalytics;

// ---------------------------------------------------------------------------
// Fake classes — for registerFallbackValue
// ---------------------------------------------------------------------------

class FakeUri() extends Fake implements Uri;

void delegateSessionRepositoryToService({
  required MockSessionRepository repository,
  required MockSessionService service,
}) {
  when(() => repository.abortSession(sessionId: any(named: "sessionId"))).thenAnswer(
    (invocation) => service.abortSession(sessionId: invocation.namedArguments[#sessionId]! as String),
  );
  when(
    () => repository.replyToQuestion(
      requestId: any(named: "requestId"),
      sessionId: any(named: "sessionId"),
      answers: any(named: "answers"),
    ),
  ).thenAnswer(
    (invocation) => service.replyToQuestion(
      requestId: invocation.namedArguments[#requestId]! as String,
      sessionId: invocation.namedArguments[#sessionId]! as String,
      answers: invocation.namedArguments[#answers]! as List<ReplyAnswer>,
    ),
  );
  when(
    () => repository.rejectQuestion(
      requestId: any(named: "requestId"),
      sessionId: any(named: "sessionId"),
    ),
  ).thenAnswer(
    (invocation) => service.rejectQuestion(
      requestId: invocation.namedArguments[#requestId]! as String,
      sessionId: invocation.namedArguments[#sessionId]! as String,
    ),
  );
  when(
    () => repository.getMessages(
      sessionId: any(named: "sessionId"),
      limit: any(named: "limit"),
      before: any(named: "before"),
    ),
  ).thenAnswer(
    (invocation) => service.getMessages(
      sessionId: invocation.namedArguments[#sessionId]! as String,
      limit: invocation.namedArguments[#limit] as int?,
      before: invocation.namedArguments[#before] as int?,
    ),
  );
  when(
    () => repository.getPendingQuestions(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (invocation) => service.getPendingQuestions(sessionId: invocation.namedArguments[#sessionId]! as String),
  );
  when(
    () => repository.getPendingPermissions(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (invocation) => service.getPendingPermissions(sessionId: invocation.namedArguments[#sessionId]! as String),
  );
  when(
    () => repository.getChildren(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (invocation) => service.getChildren(sessionId: invocation.namedArguments[#sessionId]! as String),
  );
  when(() => repository.getSessionStatuses()).thenAnswer((_) => service.getSessionStatuses());
  when(
    () => repository.listAgents(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (invocation) => service.listAgents(
      projectId: invocation.namedArguments[#projectId] as String,
      pluginId: invocation.namedArguments[#pluginId] as String,
    ),
  );
  when(
    () => repository.listProviders(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (invocation) => service.listProviders(
      projectId: invocation.namedArguments[#projectId] as String,
      pluginId: invocation.namedArguments[#pluginId] as String,
    ),
  );
  when(
    () => repository.listCommands(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (invocation) => service.listCommands(
      projectId: invocation.namedArguments[#projectId] as String?,
      pluginId: invocation.namedArguments[#pluginId] as String,
    ),
  );
  when(
    () => repository.loadSessionOptions(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
      mode: any(named: "mode"),
    ),
  ).thenAnswer((invocation) async {
    final projectId = invocation.namedArguments[#projectId]! as String;
    final pluginId = invocation.namedArguments[#pluginId]! as String;
    final (agents, providers, commands) = await (
      service.listAgents(projectId: projectId, pluginId: pluginId),
      service.listProviders(projectId: projectId, pluginId: pluginId),
      service.listCommands(projectId: projectId, pluginId: pluginId),
    ).wait;
    return switch ((agents, providers, commands)) {
      (
        SuccessResponse(data: final agentData),
        SuccessResponse(data: final providerData),
        SuccessResponse(data: final commandData),
      ) =>
        SessionOptionsRepositoryAvailable(
          catalog: SessionOptionsCatalog(
            agents: agentData.agents,
            providers: providerData.items,
            providersConnectedOnly: providerData.connectedOnly,
            commands: commandData.items,
          ),
        ),
      (ErrorResponse(:final error), _, _) => SessionOptionsRepositoryFailure(error: error),
      (_, ErrorResponse(:final error), _) => SessionOptionsRepositoryFailure(error: error),
      (_, _, ErrorResponse(:final error)) => SessionOptionsRepositoryFailure(error: error),
    };
  });
  registerFallbackValue(const <ComposerAttachment>[]);
  when(
    () => repository.sendMessage(
      promptId: any(named: "promptId"),
      sessionId: any(named: "sessionId"),
      text: any(named: "text"),
      attachments: any(named: "attachments"),
      agent: any(named: "agent"),
      model: any(named: "model"),
      variant: any(named: "variant"),
      command: any(named: "command"),
    ),
  ).thenAnswer(
    (invocation) => service.sendMessage(
      promptId: "prompt-1",
      sessionId: invocation.namedArguments[#sessionId]! as String,
      text: invocation.namedArguments[#text]! as String,
      attachments: invocation.namedArguments[#attachments]! as List<ComposerAttachment>,
      agent: invocation.namedArguments[#agent] as String?,
      providerID: (invocation.namedArguments[#model] as PromptModel?)?.providerID,
      modelID: (invocation.namedArguments[#model] as PromptModel?)?.modelID,
      variant: invocation.namedArguments[#variant] as SessionVariant?,
      command: invocation.namedArguments[#command] as String?,
    ),
  );
}

void stubSessionRepositoryGetSession({
  required MockSessionRepository repository,
  required String sessionId,
  Session? session,
}) {
  when(() => repository.getSession(sessionId: sessionId)).thenAnswer(
    (_) async => ApiResponse.success(session ?? testSession(id: sessionId)),
  );
}

// ---------------------------------------------------------------------------
// registerAllFallbackValues
// ---------------------------------------------------------------------------

/// Registers all fallback values required by mocktail argument matchers.
///
/// Call once in [setUpAll] before any test group that uses [any()] or
/// [captureAny()] for [ServerConnectionConfig] or [Uri] parameters.
void registerAllFallbackValues() {
  registerFallbackValue(const ServerConnectionConfig(relayHost: "fake.example.com"));
  registerFallbackValue(FakeUri());
  registerFallbackValue(Duration.zero);
  registerFallbackValue(const RecordConfig());
  registerFallbackValue(http.MultipartFile.fromString("audio", ""));
  registerFallbackValue(AuthProvider.github);
  registerFallbackValue(StackTrace.empty);
  registerFallbackValue(ProjectViewClaim());
  registerFallbackValue(ProjectViewPaneClaim());
  registerFallbackValue(DateTime.utc(2000));
  registerFallbackValue(SessionOptionsRequestMode.dynamic);
  registerFallbackValue(
    const ProductAnalyticsEvent.needHelpMenuOpened(surface: OnboardingSurface.connectSetup),
  );
}

// ---------------------------------------------------------------------------
// Test data factories
// ---------------------------------------------------------------------------

/// Returns a realistic [Project] instance.
Project testProject({String? id, String? path, String? name}) {
  return Project.fromJson({
    "id": id ?? "project-1",
    "path": path ?? "/home/user/my-project",
    "name": name,
    "time": {
      "created": 1700000000000,
      "updated": 1700000000000,
    },
  });
}

/// Returns a realistic [Session] instance.
ProjectSummary testProjectSummary({String? id, String? path, String? name}) {
  return ProjectSummary.fromJson({
    "id": id ?? "project-1",
    "path": path ?? "/home/user/my-project",
    "name": name,
    "time": {
      "created": 1700000000000,
      "updated": 1700000000000,
    },
  });
}

Session testSession({
  String? id,
  String? title,
  String? parentID,
  int? createdAt,
  int? updatedAt,
  DateTime? archivedAt,
  SessionPromptDefaults? promptDefaults,
  String pluginId = "plugin-1",
  String? branchName,
  int? lastUserActivityAt,
}) {
  return Session(
    branchName: branchName,
    id: id ?? "session-1",
    pluginId: pluginId,
    projectID: "project-1",
    directory: "/home/user/my-project",
    parentID: parentID,
    title: title,
    pullRequest: null,
    promptDefaults: promptDefaults,
    time: SessionTime(
      created: createdAt ?? 1700000000000,
      updated: updatedAt ?? 1700000000000,
      archived: archivedAt?.millisecondsSinceEpoch,
    ),
    lastUserActivityAt: lastUserActivityAt,
  );
}

/// Returns a realistic [HealthResponse] with [healthy] = true.
HealthResponse testHealthResponse() {
  return const HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
}

/// Returns a realistic [MessageWithParts] instance.
MessageWithParts testMessageWithParts({String? id}) {
  final messageId = id ?? "msg-1";
  return MessageWithParts(
    info: Message.assistant(
      id: messageId,
      sessionID: "session-1",
      agent: null,
      modelID: null,
      providerID: null,
      time: null,
    ),
    parts: [
      MessagePart(
        id: "part-1",
        sessionID: "session-1",
        messageID: messageId,
        type: MessagePartType.text,
        text: "Hello, world!",
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
        attachment: null,
      ),
    ],
  );
}

/// Returns a realistic [SesoriQuestionAsked] event with a single question.
SesoriQuestionAsked testSseQuestionAsked() {
  return const SesoriQuestionAsked(
    id: "question-1",
    sessionID: "session-1",
    displaySessionId: null,
    questions: [
      QuestionInfo(
        question: "Which option would you like?",
        header: "Please choose",
        options: [
          QuestionOption(label: "Yes", description: "Proceed"),
          QuestionOption(label: "No", description: "Cancel"),
        ],
      ),
    ],
  );
}

/// Returns a realistic [PendingQuestion] payload from `GET /question`.
PendingQuestion testPendingQuestion() {
  return const PendingQuestion(
    id: "question-1",
    sessionID: "session-1",
    displaySessionId: null,
    questions: [
      QuestionInfo(
        question: "Which option would you like?",
        header: "Please choose",
        options: [
          QuestionOption(label: "Yes", description: "Proceed"),
          QuestionOption(label: "No", description: "Cancel"),
        ],
      ),
    ],
  );
}

/// Returns a realistic [SesoriQuestionAsked] event with multiple questions,
/// useful for testing the multi-question stepping flow.
SesoriQuestionAsked testMultiSseQuestionAsked({
  String id = "question-multi",
  String sessionID = "session-1",
}) {
  return SesoriQuestionAsked(
    id: id,
    sessionID: sessionID,
    displaySessionId: null,
    questions: const [
      QuestionInfo(
        question: "Which language do you prefer?",
        header: "Language",
        options: [
          QuestionOption(label: "Dart", description: "Flutter language"),
          QuestionOption(label: "Kotlin", description: "Android language"),
        ],
      ),
      QuestionInfo(
        question: "Which IDE do you use?",
        header: "IDE",
        options: [
          QuestionOption(label: "VS Code", description: "Microsoft editor"),
          QuestionOption(label: "IntelliJ", description: "JetBrains IDE"),
        ],
      ),
      QuestionInfo(
        question: "Any additional notes?",
        header: "Notes",
        options: [],
        custom: true,
      ),
    ],
  );
}

/// Returns a realistic [AgentInfo] instance.
AgentInfo testAgentInfo() {
  return const AgentInfo(
    name: "coder",
    description: "A coding assistant",
    model: null,
    mode: AgentMode.primary,
  );
}

CommandInfo testCommandInfo({
  String name = "review",
  String template = "/review {{file}}",
}) {
  return CommandInfo(
    name: name,
    template: template,
    hints: const ["Optional arguments"],
    description: "Run $name",
    agent: null,
    model: null,
    provider: null,
    source: CommandSource.command,
    subtask: false,
  );
}

/// Returns a realistic [ProviderListResponse] with one provider and one model.
ProviderListResponse testProviderListResponse() {
  return const ProviderListResponse(
    connectedOnly: false,
    items: [
      ProviderInfo(
        id: "anthropic",
        name: "Anthropic",
        defaultModelID: "claude-3-5-sonnet",
        models: {
          "claude-3-5-sonnet": ProviderModel(
            id: "claude-3-5-sonnet",
            providerID: "anthropic",
            name: "Claude 3.5 Sonnet",
            variants: ["xhigh"],
            family: null,
            releaseDate: null,
          ),
        },
      ),
    ],
  );
}

/// Returns a realistic [AuthUser] instance.
AuthUser testAuthUser() {
  return const AuthUser(
    id: "user-1",
    provider: AuthProvider.github,
    providerUserId: "12345678",
    providerUsername: "testuser",
  );
}

/// Finds the brand artwork [PregoBrandLogo] draws for [pluginId].
///
/// Matched by asset rather than by rendered pixels: the artwork is what the
/// component promises for a harness it knows, and loading it would mean
/// decoding an SVG per assertion. Monochrome marks ship a `_light` and a
/// `_dark` export, so the basename is matched with that optional suffix.
Finder findBrandLogo(String pluginId) => find.byWidgetPredicate((widget) {
  if (widget is! SvgPicture) return false;
  final loader = widget.bytesLoader;
  return loader is SvgAssetLoader &&
      RegExp("/${RegExp.escape(pluginId)}(_light|_dark)?\\.svg\$").hasMatch(loader.assetName);
}, description: "brand artwork for $pluginId");
