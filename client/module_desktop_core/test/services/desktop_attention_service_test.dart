import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _user = AuthUser(
  id: "user-1",
  provider: AuthProvider.github,
  providerUserId: "provider-user-1",
  providerUsername: "alex",
);

const _session = Session(
  id: "session-root",
  pluginId: "pi",
  projectID: "project-1",
  directory: "/private/project",
  parentID: null,
  title: "Fix the build",
  time: null,
  pullRequest: null,
  promptDefaults: null,
  branchName: null,
  lastUserActivityAt: null,
);

void main() {
  setUpAll(() {
    registerFallbackValue(NotificationCategory.unknown);
    registerFallbackValue(RouteStack(paths: const <String>[]));
  });

  late _MockConnectionService connectionService;
  late _MockSessionRepository sessionRepository;
  late _MockLocalNotificationClient localNotificationClient;
  late _MockWindowHost windowHost;
  late _MockDesktopInstanceRepository desktopInstanceRepository;
  late _MockAuthSession authSession;
  late _MockRouteDispatcher routeDispatcher;
  late _MockRouteSource routeSource;
  late StreamController<SseEvent> connectionEvents;
  late StreamController<WindowHostState> windowStates;
  late StreamController<NotificationOpenRequest> notificationOpens;
  late BehaviorSubject<AuthState> authStates;
  late DesktopAttentionService service;

  setUp(() {
    connectionService = _MockConnectionService();
    sessionRepository = _MockSessionRepository();
    localNotificationClient = _MockLocalNotificationClient();
    windowHost = _MockWindowHost();
    desktopInstanceRepository = _MockDesktopInstanceRepository();
    authSession = _MockAuthSession();
    routeDispatcher = _MockRouteDispatcher();
    routeSource = _MockRouteSource();
    connectionEvents = StreamController<SseEvent>.broadcast(sync: true);
    windowStates = StreamController<WindowHostState>.broadcast(sync: true);
    notificationOpens = StreamController<NotificationOpenRequest>.broadcast(sync: true);
    authStates = BehaviorSubject<AuthState>.seeded(const AuthState.authenticated(user: _user));

    when(() => connectionService.events).thenAnswer((_) => connectionEvents.stream);
    when(() => windowHost.currentState).thenReturn(WindowHostState.hidden);
    when(() => windowHost.states).thenAnswer((_) => windowStates.stream);
    when(() => desktopInstanceRepository.readAttentionPreference()).thenAnswer(
      (_) async => DesktopAttentionPreference.enabled,
    );
    when(localNotificationClient.initialize).thenAnswer((_) async {});
    when(localNotificationClient.getInitialNotificationOpen).thenAnswer((_) async => null);
    when(() => localNotificationClient.notificationOpenedStream).thenAnswer((_) => notificationOpens.stream);
    when(() => authSession.currentState).thenAnswer((_) => authStates.value);
    when(() => authSession.authStateStream).thenAnswer((_) => authStates.stream);
    when(() => routeSource.currentLocation).thenReturn("/projects");
    when(() => routeDispatcher.replaceStack(stack: any(named: "stack"))).thenReturn(null);
    when(() => windowHost.show()).thenAnswer((_) async {});
    when(
      () => localNotificationClient.cancelForSession(sessionId: any(named: "sessionId")),
    ).thenReturn(null);

    service = DesktopAttentionService(
      connectionService: connectionService,
      sessionRepository: sessionRepository,
      localNotificationClient: localNotificationClient,
      windowHost: windowHost,
      desktopInstanceRepository: desktopInstanceRepository,
      authSession: authSession,
      routeDispatcher: routeDispatcher,
      routeSource: routeSource,
    );
  });

  tearDown(() async {
    await service.dispose();
    await connectionEvents.close();
    await windowStates.close();
    await notificationOpens.close();
    await authStates.close();
  });

  test("starts the local client and restores the desktop preference", () async {
    when(() => desktopInstanceRepository.readAttentionPreference()).thenAnswer(
      (_) async => DesktopAttentionPreference.disabled,
    );

    await service.start();

    expect(service.currentPreference, DesktopAttentionPreference.disabled);
    verify(localNotificationClient.initialize).called(1);
    verify(localNotificationClient.getInitialNotificationOpen).called(1);
  });

  test("suppresses attention while the window is focused", () async {
    when(() => windowHost.currentState).thenReturn(WindowHostState.focused);
    await service.start();

    connectionEvents.add(_permissionAsked());
    await _flushAsync();

    verifyNever(() => sessionRepository.getSession(sessionId: any(named: "sessionId")));
    verifyNever(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: any(named: "body"),
        category: any(named: "category"),
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
      ),
    );
  });

  test("suppresses attention while the persisted preference is disabled", () async {
    when(() => desktopInstanceRepository.readAttentionPreference()).thenAnswer(
      (_) async => DesktopAttentionPreference.disabled,
    );
    await service.start();

    connectionEvents.add(_questionAsked());
    await _flushAsync();

    verifyNever(() => sessionRepository.getSession(sessionId: any(named: "sessionId")));
  });

  test("shows category-only permission attention for a hidden window", () async {
    when(
      () => sessionRepository.getSession(sessionId: "session-root"),
    ).thenAnswer((_) async => ApiResponse<Session>.success(_session));
    when(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: any(named: "body"),
        category: any(named: "category"),
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
      ),
    ).thenAnswer((_) async {});
    await service.start();

    connectionEvents.add(_permissionAsked());
    await _flushAsync();

    verify(
      () => localNotificationClient.show(
        title: "Fix the build",
        body: "Permission approval needed",
        category: NotificationCategory.aiInteraction,
        sessionId: "session-root",
        projectId: "project-1",
        sessionTitle: "Fix the build",
      ),
    ).called(1);
  });

  test("classifies question attention independently of its payload", () async {
    when(
      () => sessionRepository.getSession(sessionId: "session-root"),
    ).thenAnswer((_) async => ApiResponse<Session>.success(_session));
    when(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: any(named: "body"),
        category: any(named: "category"),
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
      ),
    ).thenAnswer((_) async {});
    await service.start();

    connectionEvents.add(_questionAsked());
    await _flushAsync();

    verify(
      () => localNotificationClient.show(
        title: "Fix the build",
        body: "Question waiting for your response",
        category: NotificationCategory.aiInteraction,
        sessionId: "session-root",
        projectId: "project-1",
        sessionTitle: "Fix the build",
      ),
    ).called(1);
  });

  test("title lookup failure suppresses the notification", () async {
    when(
      () => sessionRepository.getSession(sessionId: "session-root"),
    ).thenAnswer((_) async => ApiResponse<Session>.error(ApiError.generic()));
    await service.start();

    connectionEvents.add(_permissionAsked());
    await _flushAsync();

    verifyNever(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: any(named: "body"),
        category: any(named: "category"),
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
      ),
    );
  });

  test("rechecks focus after an asynchronous title lookup", () async {
    final response = Completer<ApiResponse<Session>>();
    when(() => sessionRepository.getSession(sessionId: "session-root")).thenAnswer((_) => response.future);
    await service.start();

    connectionEvents.add(_questionAsked());
    windowStates.add(WindowHostState.focused);
    response.complete(ApiResponse<Session>.success(_session));
    await _flushAsync();

    verifyNever(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: any(named: "body"),
        category: any(named: "category"),
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
      ),
    );
  });

  test("resolved requests cancel the display session notification", () async {
    await service.start();

    connectionEvents.add(
      SseEvent(
        data: const SesoriSseEvent.questionRejected(
          requestID: "question-1",
          sessionID: "session-child",
          displaySessionId: "session-root",
        ),
      ),
    );

    verify(() => localNotificationClient.cancelForSession(sessionId: "session-root")).called(1);
  });

  test("disabling attention persists the preference and clears delivered alerts", () async {
    when(
      () => desktopInstanceRepository.writeAttentionPreference(
        preference: DesktopAttentionPreference.disabled,
      ),
    ).thenAnswer((_) async {});
    when(localNotificationClient.cancelAll).thenAnswer((_) async {});
    await service.start();

    await service.setPreference(preference: DesktopAttentionPreference.disabled);

    expect(service.currentPreference, DesktopAttentionPreference.disabled);
    verify(
      () => desktopInstanceRepository.writeAttentionPreference(
        preference: DesktopAttentionPreference.disabled,
      ),
    ).called(1);
    verify(localNotificationClient.cancelAll).called(1);
  });

  test("notification opens focus the window and replace the session stack", () async {
    await service.start();

    notificationOpens.add(
      const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-root",
        sessionTitle: "Fix the build",
      ),
    );
    await _flushAsync();

    verify(() => windowHost.show()).called(1);
    final captured =
        verify(
              () => routeDispatcher.replaceStack(stack: captureAny(named: "stack")),
            ).captured.single
            as RouteStack;
    expect(
      captured.paths,
      <String>[
        const AppRoute.projects().buildPath(),
        const AppRoute.sessions(projectId: "project-1", projectName: null).buildPath(),
        const AppRoute.sessionDetail(
          projectId: "project-1",
          projectName: null,
          sessionId: "session-root",
          sessionTitle: "Fix the build",
          readOnly: false,
        ).buildPath(),
      ],
    );
  });

  test("an initial open waits for authenticated session restoration", () async {
    authStates.add(const AuthState.initial());
    when(localNotificationClient.getInitialNotificationOpen).thenAnswer(
      (_) async => const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-root",
        sessionTitle: null,
      ),
    );
    await service.start();
    verifyNever(() => windowHost.show());

    authStates.add(const AuthState.authenticated(user: _user));
    await _flushAsync();

    verify(() => windowHost.show()).called(1);
    verify(() => routeDispatcher.replaceStack(stack: any(named: "stack"))).called(1);
  });
}

SseEvent _permissionAsked() {
  return SseEvent(
    data: const SesoriSseEvent.permissionAsked(
      requestID: "permission-1",
      sessionID: "session-child",
      displaySessionId: "session-root",
      tool: "secret-tool-name",
      description: "sensitive permission payload",
    ),
  );
}

SseEvent _questionAsked() {
  return SseEvent(
    data: const SesoriSseEvent.questionAsked(
      id: "question-1",
      sessionID: "session-child",
      displaySessionId: "session-root",
      questions: <QuestionInfo>[],
    ),
  );
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _MockConnectionService() extends Mock implements ConnectionService;

class _MockSessionRepository() extends Mock implements SessionRepository;

class _MockLocalNotificationClient() extends Mock implements LocalNotificationClient;

class _MockWindowHost() extends Mock implements WindowHost;

class _MockDesktopInstanceRepository() extends Mock implements DesktopInstanceRepository;

class _MockAuthSession() extends Mock implements AuthSession;

class _MockRouteDispatcher() extends Mock implements RouteDispatcher;

class _MockRouteSource() extends Mock implements RouteSource;
