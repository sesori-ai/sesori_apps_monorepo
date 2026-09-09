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

const _otherUser = AuthUser(
  id: "user-2",
  provider: AuthProvider.github,
  providerUserId: "provider-user-2",
  providerUsername: "sam",
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
    when(localNotificationClient.cancelAll).thenAnswer((_) async {});
    when(() => localNotificationClient.notificationOpenedStream).thenAnswer((_) => notificationOpens.stream);
    when(() => authSession.currentState).thenAnswer((_) => authStates.value);
    when(() => authSession.authStateStream).thenAnswer((_) => authStates.stream);
    when(authSession.hasLocallyValidSession).thenAnswer((_) async => false);
    when(() => routeSource.currentLocation).thenReturn("/projects");
    when(() => routeDispatcher.replaceStack(stack: any(named: "stack"))).thenReturn(null);
    when(() => windowHost.show()).thenAnswer((_) async {});
    when(
      () => localNotificationClient.cancelForSession(sessionId: any(named: "sessionId")),
    ).thenAnswer((_) async {});

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

  test("subscribes before initialization can emit a Linux launch open", () async {
    when(localNotificationClient.initialize).thenAnswer((_) async {
      notificationOpens.add(
        const NotificationOpenRequest(
          projectId: "project-1",
          sessionId: "session-root",
          sessionTitle: "Fix the build",
          accountId: "user-1",
        ),
      );
    });

    await service.start();
    await _flushAsync();

    verify(() => windowHost.show()).called(1);
    verify(() => routeDispatcher.replaceStack(stack: any(named: "stack"))).called(1);
  });

  test("tracks window state while native initialization is pending", () async {
    final initialization = Completer<void>();
    when(() => windowHost.currentState).thenReturn(WindowHostState.focused);
    when(localNotificationClient.initialize).thenAnswer((_) => initialization.future);
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) async {});

    final start = service.start();
    await _flushAsync();
    windowStates.add(WindowHostState.unfocused);
    initialization.complete();
    await start;
    connectionEvents.add(_permissionAsked());
    await pumpEventQueue(times: 20);

    verify(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: any(named: "body"),
        category: any(named: "category"),
        sessionId: "session-root",
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
        accountId: "user-1",
      ),
    ).called(1);
  });

  test("captures relay attention while native initialization is pending", () async {
    final initialization = Completer<void>();
    when(localNotificationClient.initialize).thenAnswer((_) => initialization.future);
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) async {});

    final start = service.start();
    await _flushAsync();
    connectionEvents.add(_permissionAsked());
    initialization.complete();
    await start;
    await pumpEventQueue(times: 20);

    verify(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: "Permission approval needed",
        category: any(named: "category"),
        sessionId: "session-root",
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
        accountId: "user-1",
      ),
    ).called(1);
  });

  test("retries transient native initialization on a later attention event", () async {
    var initializationAttempts = 0;
    when(localNotificationClient.initialize).thenAnswer((_) async {
      initializationAttempts++;
      if (initializationAttempts == 1) {
        throw StateError("native initialization unavailable");
      }
    });
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) async {});

    await service.start();
    connectionEvents.add(_permissionAsked());
    await pumpEventQueue(times: 20);

    verify(localNotificationClient.initialize).called(2);
    verify(
      () => localNotificationClient.show(
        title: "Fix the build",
        body: "Permission approval needed",
        category: NotificationCategory.aiInteraction,
        sessionId: "session-root",
        projectId: "project-1",
        sessionTitle: "Fix the build",
        accountId: "user-1",
      ),
    ).called(1);
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
        accountId: any(named: "accountId"),
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

  test("shows pending attention after the focused window becomes unfocused", () async {
    when(() => windowHost.currentState).thenReturn(WindowHostState.focused);
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) async {});
    await service.start();

    connectionEvents.add(_permissionAsked());
    await _flushAsync();
    verifyNever(() => sessionRepository.getSession(sessionId: any(named: "sessionId")));

    windowStates.add(WindowHostState.unfocused);
    await pumpEventQueue(times: 20);

    verify(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: any(named: "body"),
        category: any(named: "category"),
        sessionId: "session-root",
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
        accountId: "user-1",
      ),
    ).called(1);
  });

  test("shows pending attention after the preference is re-enabled", () async {
    when(() => desktopInstanceRepository.readAttentionPreference()).thenAnswer(
      (_) async => DesktopAttentionPreference.disabled,
    );
    when(
      () => desktopInstanceRepository.writeAttentionPreference(
        preference: DesktopAttentionPreference.enabled,
      ),
    ).thenAnswer((_) async {});
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) async {});
    await service.start();

    connectionEvents.add(_questionAsked());
    await _flushAsync();
    await service.setPreference(preference: DesktopAttentionPreference.enabled);
    await pumpEventQueue(times: 20);

    verify(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: "Question waiting for your response",
        category: any(named: "category"),
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
        accountId: "user-1",
      ),
    ).called(1);
  });

  test("shows pending attention after authentication restoration", () async {
    authStates.add(const AuthState.initial());
    when(authSession.hasLocallyValidSession).thenAnswer((_) async => true);
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) async {});
    await service.start();

    connectionEvents.add(_permissionAsked());
    await _flushAsync();
    authStates.add(const AuthState.authenticated(user: _user));
    await pumpEventQueue(times: 20);

    verify(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: any(named: "body"),
        category: any(named: "category"),
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
        accountId: "user-1",
      ),
    ).called(1);
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
        accountId: any(named: "accountId"),
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
        accountId: "user-1",
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
        accountId: any(named: "accountId"),
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
        accountId: "user-1",
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
        accountId: any(named: "accountId"),
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
        accountId: any(named: "accountId"),
      ),
    );
  });

  test("a resolved request cannot reappear after its title lookup completes", () async {
    final response = Completer<ApiResponse<Session>>();
    when(() => sessionRepository.getSession(sessionId: "session-root")).thenAnswer((_) => response.future);
    await service.start();

    connectionEvents.add(_permissionAsked());
    connectionEvents.add(_permissionReplied(requestId: "permission-1"));
    response.complete(ApiResponse<Session>.success(_session));
    await _flushAsync();

    verify(() => localNotificationClient.cancelForSession(sessionId: "session-root")).called(1);
    verifyNever(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: any(named: "body"),
        category: any(named: "category"),
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
        accountId: any(named: "accountId"),
      ),
    );
  });

  test("resolution waits for a started native alert before cancelling it", () async {
    final nativeWrite = Completer<void>();
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) => nativeWrite.future);
    await service.start();

    connectionEvents.add(_permissionAsked());
    await _flushAsync();
    connectionEvents.add(_permissionReplied(requestId: "permission-1"));
    await _flushAsync();
    verifyNever(() => localNotificationClient.cancelForSession(sessionId: "session-root"));

    nativeWrite.complete();
    await _flushAsync();
    verify(() => localNotificationClient.cancelForSession(sessionId: "session-root")).called(1);
  });

  test("serializes a replacement alert after the resolved alert cancellation", () async {
    final cancellation = Completer<void>();
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) async {});
    when(
      () => localNotificationClient.cancelForSession(sessionId: "session-root"),
    ).thenAnswer((_) => cancellation.future);
    await service.start();

    connectionEvents.add(_permissionAsked());
    await pumpEventQueue(times: 20);
    connectionEvents.add(_permissionReplied(requestId: "permission-1"));
    await pumpEventQueue(times: 20);
    verify(() => localNotificationClient.cancelForSession(sessionId: "session-root")).called(1);

    connectionEvents.add(_questionAsked());
    await pumpEventQueue(times: 20);
    verify(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: "Permission approval needed",
        category: any(named: "category"),
        sessionId: "session-root",
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
        accountId: any(named: "accountId"),
      ),
    ).called(1);

    cancellation.complete();
    await pumpEventQueue(times: 20);
    verify(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: "Question waiting for your response",
        category: any(named: "category"),
        sessionId: "session-root",
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
        accountId: any(named: "accountId"),
      ),
    ).called(1);
  });

  test("serializes native writes so the latest request owns the session alert", () async {
    final firstWrite = Completer<void>();
    var showCalls = 0;
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) {
      showCalls++;
      return showCalls == 1 ? firstWrite.future : Future<void>.value();
    });
    await service.start();

    connectionEvents.add(_permissionAsked());
    await pumpEventQueue(times: 20);
    expect(showCalls, 1);

    connectionEvents.add(_questionAsked());
    await pumpEventQueue(times: 20);
    expect(showCalls, 1);

    firstWrite.complete();
    await pumpEventQueue(times: 20);
    expect(showCalls, 2);
    final bodies = verify(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: captureAny(named: "body"),
        category: any(named: "category"),
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
        accountId: any(named: "accountId"),
      ),
    ).captured;
    expect(
      bodies,
      <String>[
        "Permission approval needed",
        "Question waiting for your response",
      ],
    );
  });

  test("keeps a session alert until its last outstanding request resolves", () async {
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) async {});
    await service.start();

    connectionEvents.add(_permissionAsked());
    connectionEvents.add(_questionAsked());
    await _flushAsync();
    connectionEvents.add(_permissionReplied(requestId: "permission-1"));
    await _flushAsync();

    verifyNever(() => localNotificationClient.cancelForSession(sessionId: "session-root"));

    connectionEvents.add(
      SseEvent(
        data: const SesoriSseEvent.questionRejected(
          requestID: "question-1",
          sessionID: "session-child",
          displaySessionId: "session-root",
        ),
      ),
    );
    await _flushAsync();

    verify(() => localNotificationClient.cancelForSession(sessionId: "session-root")).called(1);
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
    await _flushAsync();

    verify(() => localNotificationClient.cancelForSession(sessionId: "session-root")).called(1);
  });

  test("disabling attention clears delivered alerts when initialization is unavailable", () async {
    when(
      () => desktopInstanceRepository.writeAttentionPreference(
        preference: DesktopAttentionPreference.disabled,
      ),
    ).thenAnswer((_) async {});
    when(localNotificationClient.initialize).thenThrow(StateError("native initialization unavailable"));
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

  test("authentication loss attempts cleanup when initialization is unavailable", () async {
    when(localNotificationClient.initialize).thenThrow(StateError("native initialization unavailable"));
    await service.start();

    authStates.add(const AuthState.unauthenticated());
    await _flushAsync();
    authStates.add(const AuthState.authenticated(user: _otherUser));
    await _flushAsync();
    notificationOpens.add(
      const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-root",
        sessionTitle: "Fix the build",
        accountId: "user-1",
      ),
    );
    await _flushAsync();

    verify(localNotificationClient.cancelAll).called(1);
    verifyNever(() => windowHost.show());
    verifyNever(() => routeDispatcher.replaceStack(stack: any(named: "stack")));
  });

  test("authentication cleanup fences and then restores new-account attention", () async {
    final oldAccountWrite = Completer<void>();
    final operations = <String>[];
    var showCalls = 0;
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) {
      showCalls++;
      if (showCalls == 1) {
        operations.add("show-account-a");
        return oldAccountWrite.future;
      }
      operations.add("show-account-b");
      return Future<void>.value();
    });
    when(localNotificationClient.cancelAll).thenAnswer((_) async => operations.add("cancel-account-a"));
    await service.start();

    connectionEvents.add(_permissionAsked());
    await _flushAsync();
    authStates.add(const AuthState.unauthenticated());
    await _flushAsync();
    authStates.add(const AuthState.authenticated(user: _otherUser));
    await _flushAsync();
    connectionEvents.add(_questionAsked());
    await _flushAsync();

    expect(operations, <String>["show-account-a"]);

    oldAccountWrite.complete();
    await pumpEventQueue(times: 20);

    expect(
      operations,
      <String>["show-account-a", "cancel-account-a", "show-account-b"],
    );
  });

  test("logout cleanup waits for native writes, cancels all, and fences later alerts", () async {
    final nativeWrite = Completer<void>();
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) => nativeWrite.future);
    await service.start();
    connectionEvents.add(_permissionAsked());
    await _flushAsync();

    var settled = false;
    final settlement = service.suspendAndClearForLogout();
    unawaited(settlement.then((_) => settled = true));
    await _flushAsync();
    expect(settled, isFalse);

    connectionEvents.add(_questionAsked());
    nativeWrite.complete();
    await settlement;
    await _flushAsync();

    verify(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: any(named: "body"),
        category: any(named: "category"),
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
        accountId: any(named: "accountId"),
      ),
    ).called(1);
    verify(localNotificationClient.cancelAll).called(1);
  });

  test("completed logout discards old alerts without keeping attention suspended", () async {
    when(() => windowHost.currentState).thenReturn(WindowHostState.focused);
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
        accountId: any(named: "accountId"),
      ),
    ).thenAnswer((_) async {});
    await service.start();

    connectionEvents.add(_permissionAsked());
    await service.suspendAndClearForLogout();
    service.completeSuccessfulLogout();
    windowStates.add(WindowHostState.unfocused);
    await _flushAsync();
    verifyNever(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: any(named: "body"),
        category: any(named: "category"),
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
        accountId: any(named: "accountId"),
      ),
    );

    connectionEvents.add(_questionAsked());
    await pumpEventQueue(times: 20);
    verify(
      () => localNotificationClient.show(
        title: any(named: "title"),
        body: "Question waiting for your response",
        category: any(named: "category"),
        sessionId: "session-root",
        projectId: any(named: "projectId"),
        sessionTitle: any(named: "sessionTitle"),
        accountId: "user-1",
      ),
    ).called(1);
  });

  test("notification opens focus the window and replace the session stack", () async {
    await service.start();

    notificationOpens.add(
      const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-root",
        sessionTitle: "Fix the build",
        accountId: "user-1",
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

  test("does not route an old-account notification after window focus awaits", () async {
    final windowFocus = Completer<void>();
    when(() => windowHost.show()).thenAnswer((_) => windowFocus.future);
    await service.start();

    notificationOpens.add(
      const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-root",
        sessionTitle: "Fix the build",
        accountId: "user-1",
      ),
    );
    await _flushAsync();
    authStates.add(const AuthState.authenticated(user: _otherUser));
    windowFocus.complete();
    await _flushAsync();

    verify(() => windowHost.show()).called(1);
    verifyNever(() => routeDispatcher.replaceStack(stack: any(named: "stack")));
  });

  test("drops an initial open when no local session can be restored", () async {
    authStates.add(const AuthState.initial());
    when(localNotificationClient.getInitialNotificationOpen).thenAnswer(
      (_) async => const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-root",
        sessionTitle: null,
        accountId: "user-1",
      ),
    );
    await service.start();

    authStates.add(const AuthState.authenticated(user: _otherUser));
    await _flushAsync();

    verifyNever(() => windowHost.show());
    verifyNever(() => routeDispatcher.replaceStack(stack: any(named: "stack")));
  });

  test("an initial open waits for authenticated session restoration", () async {
    authStates.add(const AuthState.initial());
    when(authSession.hasLocallyValidSession).thenAnswer((_) async => true);
    when(localNotificationClient.getInitialNotificationOpen).thenAnswer(
      (_) async => const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-root",
        sessionTitle: null,
        accountId: "user-1",
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

SseEvent _permissionReplied({required String requestId}) {
  return SseEvent(
    data: SesoriSseEvent.permissionReplied(
      requestID: requestId,
      sessionID: "session-child",
      displaySessionId: "session-root",
      reply: "once",
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
