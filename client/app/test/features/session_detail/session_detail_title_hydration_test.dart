import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/features/session_detail/session_detail_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class MockSessionDetailLoadService() extends Mock implements SessionDetailLoadService;

class MockSessionRepository() extends Mock implements SessionRepository;

class MockPermissionRepository() extends Mock implements PermissionRepository;

class MockVoiceTranscriptionService() extends Mock implements VoiceTranscriptionService;

Widget _buildApp({required String? sessionTitle, required GlobalKey<NavigatorState>? navigatorKey}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ConnectionOverlayCubit>(create: (_) => StubConnectionOverlayCubit()),
      BlocProvider<ChatInputModeCubit>(create: (_) => StubChatInputModeCubit()),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SessionDetailScreen(
        projectId: "project-1",
        projectName: null,
        sessionId: "session-1",
        sessionTitle: sessionTitle,
      ),
    ),
  );
}

SessionDetailLoadResult _loadedResult() {
  return const SessionDetailLoadResult.loaded(
    snapshot: SessionDetailSnapshot(
      projectId: "project-1",
      pluginId: "opencode",
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
  );
}

SessionDetailLoadResult _loadedResultWithCanonicalTitle(String title) {
  return SessionDetailLoadResult.loaded(
    snapshot: SessionDetailSnapshot(
      projectId: "project-1",
      pluginId: "opencode",
      supportsPromptAttachments: false,
      messages: const [],
      olderMessagesCursor: null,
      pendingQuestions: const [],
      pendingPermissions: const [],
      childSessions: const [],
      statuses: const {},
      agents: const [],
      providerData: null,
      commands: const [],
      canonicalSessionTitle: title,
      promptDefaults: null,
      isRootSession: true,
      isArchived: false,
    ),
    isBridgeConnected: true,
  );
}

SessionDetailLoadResult _loadedResultWithPendingQuestion() {
  return const SessionDetailLoadResult.loaded(
    snapshot: SessionDetailSnapshot(
      projectId: "project-1",
      pluginId: "opencode",
      supportsPromptAttachments: false,
      messages: [],
      olderMessagesCursor: null,
      pendingQuestions: [
        PendingQuestion(
          id: "question-1",
          sessionID: "session-1",
          displaySessionId: null,
          questions: [],
        ),
      ],
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
  );
}

void _registerDependencies({
  required MockSessionDetailLoadService loadService,
  required MockConnectionService connectionService,
  required MockSessionRepository promptDispatcher,
  required MockPermissionRepository permissionRepository,
  required MockNotificationCanceller notificationCanceller,
  required MockFailureReporter failureReporter,
  required MockVoiceTranscriptionService voiceTranscriptionService,
  required MockProductAnalyticsService productAnalyticsService,
}) {
  final getIt = GetIt.instance;

  getIt.registerSingleton<ConnectionService>(connectionService);
  getIt.registerSingleton<SessionDetailLoadService>(loadService);
  getIt.registerSingleton<SessionRepository>(promptDispatcher);
  getIt.registerSingleton<PermissionRepository>(permissionRepository);
  getIt.registerSingleton<SessionViewingService>(stubbedSessionViewingService());
  getIt.registerSingleton<ProjectViewingService>(stubbedProjectViewingService());
  getIt.registerSingleton<LifecycleSource>(MockLifecycleSource());
  getIt.registerSingleton<NotificationCanceller>(notificationCanceller);
  getIt.registerSingleton<FailureReporter>(failureReporter);
  getIt.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
  getIt.registerSingleton<ComposerDraftRepository>(inMemoryComposerDraftRepository());
  getIt.registerSingleton<ProductAnalyticsService>(productAnalyticsService);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);

  late MockConnectionService connectionService;
  late MockSessionDetailLoadService loadService;
  late MockSessionRepository promptDispatcher;
  late MockPermissionRepository permissionRepository;
  late MockNotificationCanceller notificationCanceller;
  late MockFailureReporter failureReporter;
  late MockVoiceTranscriptionService voiceTranscriptionService;
  late MockProductAnalyticsService productAnalyticsService;
  late StreamController<SesoriSessionEvent> sessionEvents;
  late StreamController<SseEvent> globalEvents;
  late BehaviorSubject<ConnectionStatus> connectionStatus;

  setUp(() async {
    final getIt = GetIt.instance;
    await getIt.reset();

    connectionService = MockConnectionService();
    loadService = MockSessionDetailLoadService();
    promptDispatcher = MockSessionRepository();
    permissionRepository = MockPermissionRepository();
    notificationCanceller = MockNotificationCanceller();
    failureReporter = MockFailureReporter();
    voiceTranscriptionService = MockVoiceTranscriptionService();
    productAnalyticsService = MockProductAnalyticsService();
    stubProductAnalyticsService(service: productAnalyticsService);
    sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
    globalEvents = StreamController<SseEvent>.broadcast();
    connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(
      ConnectionStatus.connected(
        config: const ServerConnectionConfig(relayHost: "fake.example.com"),
        health: testHealthResponse(),
      ),
    );

    when(() => connectionService.sessionEvents(any())).thenAnswer((_) => sessionEvents.stream);
    when(() => connectionService.events).thenAnswer((_) => globalEvents.stream);
    when(() => connectionService.status).thenAnswer((_) => connectionStatus.stream);
    when(() => connectionService.currentStatus).thenReturn(
      ConnectionStatus.connected(
        config: const ServerConnectionConfig(relayHost: "fake.example.com"),
        health: testHealthResponse(),
      ),
    );

    final maxDurationReached = StreamController<void>.broadcast();
    addTearDown(maxDurationReached.close);
    when(() => voiceTranscriptionService.onMaxDurationReached).thenAnswer((_) => maxDurationReached.stream);
    when(() => voiceTranscriptionService.prewarmRecording()).thenAnswer((_) async {});

    when(
      () => loadService.load(
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer((_) async => _loadedResult());
    when(
      () => loadService.reload(
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer((_) async => _loadedResult());

    _registerDependencies(
      loadService: loadService,
      connectionService: connectionService,
      promptDispatcher: promptDispatcher,
      permissionRepository: permissionRepository,
      notificationCanceller: notificationCanceller,
      failureReporter: failureReporter,
      voiceTranscriptionService: voiceTranscriptionService,
      productAnalyticsService: productAnalyticsService,
    );
  });

  tearDown(() async {
    await sessionEvents.close();
    await globalEvents.close();
    await connectionStatus.close();
    await GetIt.instance.reset();
  });

  testWidgets("shows carried title during loading and before canonical data arrives", (tester) async {
    final loadCompleter = Completer<SessionDetailLoadResult>();
    when(
      () => loadService.load(
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer((_) => loadCompleter.future);

    await tester.pumpWidget(_buildApp(sessionTitle: "Carried title", navigatorKey: null));
    await tester.pump();

    final loc = AppLocalizations.of(tester.element(find.byType(SessionDetailScreen)))!;
    expect(find.text("Carried title"), findsOneWidget);
    expect(find.byType(PregoLaunchStatus), findsOneWidget);
    expect(find.bySemanticsLabel(loc.sessionDetailLoadingSemantics), findsOneWidget);

    loadCompleter.complete(_loadedResult());
    await tester.pumpAndSettle();

    expect(find.text("Carried title"), findsOneWidget);
  });

  testWidgets("shows carried title on failed load and keeps retry wired to reload", (tester) async {
    when(
      () => loadService.load(
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer((_) async => const SessionDetailLoadResult.failed(error: Object(), stackTrace: null));

    await tester.pumpWidget(_buildApp(sessionTitle: "Carried title", navigatorKey: null));
    await tester.pumpAndSettle();

    expect(find.text("Carried title"), findsOneWidget);
    expect(find.text("Retry"), findsOneWidget);

    await tester.tap(find.text("Retry"));
    await tester.pumpAndSettle();

    verify(
      () => loadService.reload(
        sessionId: "session-1",
        projectId: any(named: "projectId"),
      ),
    ).called(1);
  });

  testWidgets("canonical title overrides the carried route title", (tester) async {
    when(
      () => loadService.load(
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer((_) async => _loadedResultWithCanonicalTitle("Canonical title"));

    await tester.pumpWidget(_buildApp(sessionTitle: "Carried title", navigatorKey: null));
    await tester.pumpAndSettle();

    expect(find.text("Canonical title"), findsOneWidget);
    expect(find.text("Carried title"), findsNothing);
  });

  testWidgets("later SSE title update still overrides the currently loaded title", (tester) async {
    when(
      () => loadService.load(
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer((_) async => _loadedResultWithCanonicalTitle("Canonical title"));

    await tester.pumpWidget(_buildApp(sessionTitle: "Carried title", navigatorKey: null));
    await tester.pumpAndSettle();

    sessionEvents.add(
      SesoriSessionUpdated(
        info: testSession(title: "Newest title"),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Newest title"), findsOneWidget);
    expect(find.text("Canonical title"), findsNothing);
  });

  testWidgets("falls back to the localized title when both titles are null", (tester) async {
    await tester.pumpWidget(_buildApp(sessionTitle: null, navigatorKey: null));
    await tester.pumpAndSettle();

    expect(find.text("Session"), findsOneWidget);
  });

  testWidgets("covered detail routes do not report activity until visible again", (tester) async {
    final loadCompleter = Completer<SessionDetailLoadResult>();
    when(
      () => loadService.load(
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer((_) => loadCompleter.future);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _buildApp(
        sessionTitle: "Carried title",
        navigatorKey: navigatorKey,
      ),
    );
    await tester.pump();

    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text("Covering route"))),
    );
    await tester.pumpAndSettle();
    clearInteractions(productAnalyticsService);

    loadCompleter.complete(_loadedResultWithPendingQuestion());
    await tester.pumpAndSettle();
    verifyNever(
      () => productAnalyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    );

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    verify(
      () => productAnalyticsService.logEvent(
        event: const ProductAnalyticsEvent.sessionActivityViewed(
          activityState: AnalyticsActivityState.nonEmpty,
        ),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).called(1);
  });
}
