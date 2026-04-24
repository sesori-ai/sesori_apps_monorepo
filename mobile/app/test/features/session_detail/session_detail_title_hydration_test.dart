import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/features/session_detail/session_detail_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

class MockSessionDetailLoadService extends Mock implements SessionDetailLoadService {}

class MockSessionRepository extends Mock implements SessionRepository {}

class MockPermissionRepository extends Mock implements PermissionRepository {}

class MockVoiceTranscriptionService extends Mock implements VoiceTranscriptionService {}

Widget _buildApp({required String? sessionTitle}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SessionDetailScreen(
      projectId: "project-1",
      sessionId: "session-1",
      sessionTitle: sessionTitle,
    ),
  );
}

SessionDetailLoadResult _loadedResult() {
  return const SessionDetailLoadResult.loaded(
    snapshot: SessionDetailSnapshot(
      projectId: "project-1",
      messages: [],
      pendingQuestions: [],
      childSessions: [],
      statuses: {},
      agents: [],
      providerData: null,
      commands: [],
      canonicalSessionTitle: null,
    ),
    isBridgeConnected: true,
  );
}

SessionDetailLoadResult _loadedResultWithCanonicalTitle(String title) {
  return SessionDetailLoadResult.loaded(
    snapshot: SessionDetailSnapshot(
      projectId: "project-1",
      messages: const [],
      pendingQuestions: const [],
      childSessions: const [],
      statuses: const {},
      agents: const [],
      providerData: null,
      commands: const [],
      canonicalSessionTitle: title,
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
}) {
  final getIt = GetIt.instance;

  getIt.registerSingleton<ConnectionService>(connectionService);
  getIt.registerSingleton<SessionDetailLoadService>(loadService);
  getIt.registerSingleton<SessionRepository>(promptDispatcher);
  getIt.registerSingleton<PermissionRepository>(permissionRepository);
  getIt.registerSingleton<AgentVariantOptionsBuilder>(const AgentVariantOptionsBuilder());
  getIt.registerSingleton<NotificationCanceller>(notificationCanceller);
  getIt.registerSingleton<FailureReporter>(failureReporter);
  getIt.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
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

    when(
      () => loadService.load(sessionId: any(named: "sessionId"), projectId: any(named: "projectId")),
    ).thenAnswer((_) async => _loadedResult());
    when(
      () => loadService.reload(sessionId: any(named: "sessionId"), projectId: any(named: "projectId")),
    ).thenAnswer((_) async => _loadedResult());

    _registerDependencies(
      loadService: loadService,
      connectionService: connectionService,
      promptDispatcher: promptDispatcher,
      permissionRepository: permissionRepository,
      notificationCanceller: notificationCanceller,
      failureReporter: failureReporter,
      voiceTranscriptionService: voiceTranscriptionService,
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
      () => loadService.load(sessionId: any(named: "sessionId"), projectId: any(named: "projectId")),
    ).thenAnswer((_) => loadCompleter.future);

    await tester.pumpWidget(_buildApp(sessionTitle: "Carried title"));
    await tester.pump();

    expect(find.text("Carried title"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    loadCompleter.complete(_loadedResult());
    await tester.pumpAndSettle();

    expect(find.text("Carried title"), findsOneWidget);
  });

  testWidgets("shows carried title on failed load and keeps retry wired to reload", (tester) async {
    when(
      () => loadService.load(sessionId: any(named: "sessionId"), projectId: any(named: "projectId")),
    ).thenAnswer((_) async => const SessionDetailLoadResult.failed(error: Object(), stackTrace: null));

    await tester.pumpWidget(_buildApp(sessionTitle: "Carried title"));
    await tester.pumpAndSettle();

    expect(find.text("Carried title"), findsOneWidget);
    expect(find.text("Retry"), findsOneWidget);

    await tester.tap(find.text("Retry"));
    await tester.pumpAndSettle();

    verify(
      () => loadService.reload(sessionId: "session-1", projectId: any(named: "projectId")),
    ).called(1);
  });

  testWidgets("canonical title overrides the carried route title", (tester) async {
    when(
      () => loadService.load(sessionId: any(named: "sessionId"), projectId: any(named: "projectId")),
    ).thenAnswer((_) async => _loadedResultWithCanonicalTitle("Canonical title"));

    await tester.pumpWidget(_buildApp(sessionTitle: "Carried title"));
    await tester.pumpAndSettle();

    expect(find.text("Canonical title"), findsOneWidget);
    expect(find.text("Carried title"), findsNothing);
  });

  testWidgets("later SSE title update still overrides the currently loaded title", (tester) async {
    when(
      () => loadService.load(sessionId: any(named: "sessionId"), projectId: any(named: "projectId")),
    ).thenAnswer((_) async => _loadedResultWithCanonicalTitle("Canonical title"));

    await tester.pumpWidget(_buildApp(sessionTitle: "Carried title"));
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
    await tester.pumpWidget(_buildApp(sessionTitle: null));
    await tester.pumpAndSettle();

    expect(find.text("Session"), findsOneWidget);
  });
}
