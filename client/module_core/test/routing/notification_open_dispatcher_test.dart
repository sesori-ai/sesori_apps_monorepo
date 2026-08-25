import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/platform/local_notification_client.dart";
import "package:sesori_dart_core/src/platform/notification_open_request.dart";
import "package:sesori_dart_core/src/platform/push_messaging_source.dart";
import "package:sesori_dart_core/src/platform/push_notification_message.dart";
import "package:sesori_dart_core/src/platform/route_dispatcher.dart";
import "package:sesori_dart_core/src/platform/route_source.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_dart_core/src/routing/notification_open_dispatcher.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("NotificationOpenDispatcher", () {
    late FakeAuthSession authSession;
    late FakePushMessagingSource pushMessagingSource;
    late FakeLocalNotificationClient localNotificationClient;
    late RecordingRouteDispatcher routeDispatcher;
    late FakeRouteSource routeSource;
    late NotificationOpenDispatcher dispatcher;

    setUp(() {
      authSession = FakeAuthSession(initialState: _authenticatedState());
      pushMessagingSource = FakePushMessagingSource();
      localNotificationClient = FakeLocalNotificationClient();
      routeDispatcher = RecordingRouteDispatcher();
      routeSource = FakeRouteSource();
      dispatcher = NotificationOpenDispatcher(
        authSession: authSession,
        pushMessagingSource: pushMessagingSource,
        localNotificationClient: localNotificationClient,
        routeDispatcher: routeDispatcher,
        routeSource: routeSource,
      );
    });

    tearDown(() async {
      await dispatcher.dispose();
      await authSession.dispose();
      await pushMessagingSource.dispose();
      await localNotificationClient.dispose();
    });

    test("rebuilds projects -> sessions -> detail stack through route dispatcher", () async {
      pushMessagingSource.initialOpenRequest = const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-1",
        sessionTitle: "Weekly planning",
      );

      await dispatcher.start();

      expect(routeDispatcher.replacedStacks, hasLength(1));
      final stack = routeDispatcher.replacedStacks.single;
      expect(
        stack.paths,
        equals([
          const AppRoute.projects().buildPath(),
          const AppRoute.sessions(
            projectId: "project-1",
            projectName: null,
          ).buildPath(),
          const AppRoute.sessionDetail(
            projectId: "project-1",
            projectName: null,
            sessionId: "session-1",
            sessionTitle: "Weekly planning",
            readOnly: false,
            bridgeId: null,
          ).buildPath(),
        ]),
      );
    });

    test("leaves the stack alone when that session detail is already on top", () async {
      // Display-only query parameters differ from what the notification would
      // build; they must not defeat the match.
      routeSource.currentLocation = "/projects/project-1/sessions/session-1?readOnly=false&title=Renamed";
      pushMessagingSource.initialOpenRequest = const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-1",
        sessionTitle: "Weekly planning",
      );

      await dispatcher.start();

      // Rebuilding would tear down the live screen and force a full reload
      // before the prompt could show; the mounted screen already surfaces it.
      expect(routeDispatcher.replacedStacks, isEmpty);
    });

    test("rebuilds when that session is shown read-only", () async {
      // Background tasks and subtasks open the same session on the read-only
      // route, which renders without the composer. The notification wants the
      // editable screen, so it must still navigate.
      routeSource.currentLocation = "/projects/project-1/sessions/session-1?readOnly=true";
      pushMessagingSource.initialOpenRequest = const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-1",
        sessionTitle: "Weekly planning",
      );

      await dispatcher.start();

      expect(routeDispatcher.replacedStacks, hasLength(1));
    });

    test("rebuilds when that session is gated to a Device Canvas bridge", () async {
      routeSource.currentLocation = "/projects/project-1/sessions/session-1?readOnly=false&bridgeId=bridge-1";
      pushMessagingSource.initialOpenRequest = const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-1",
        sessionTitle: "Weekly planning",
      );

      await dispatcher.start();

      expect(routeDispatcher.replacedStacks, hasLength(1));
    });

    test("rebuilds the stack when a different session is on top", () async {
      routeSource.currentLocation = "/projects/project-1/sessions/session-2";
      pushMessagingSource.initialOpenRequest = const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-1",
        sessionTitle: "Weekly planning",
      );

      await dispatcher.start();

      expect(routeDispatcher.replacedStacks, hasLength(1));
    });

    test("rebuilds the stack when a pushed screen sits above that session", () async {
      routeSource.currentLocation = "/projects/project-1/sessions/session-1/diffs";
      pushMessagingSource.initialOpenRequest = const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-1",
        sessionTitle: "Weekly planning",
      );

      await dispatcher.start();

      expect(routeDispatcher.replacedStacks, hasLength(1));
    });

    test("latest pending notification wins after auth replay", () async {
      authSession.emit(const AuthState.unauthenticated());
      final initialOpenCompleter = Completer<NotificationOpenRequest?>();
      pushMessagingSource.initialOpenRequestFuture = initialOpenCompleter.future;

      final startFuture = dispatcher.start();
      initialOpenCompleter.complete(
        const NotificationOpenRequest(
          projectId: "project-1",
          sessionId: "session-1",
          sessionTitle: "First title",
        ),
      );
      await startFuture;

      localNotificationClient.emitOpen(
        const NotificationOpenRequest(
          projectId: "project-2",
          sessionId: "session-2",
          sessionTitle: "Latest title",
        ),
      );
      await Future<void>.delayed(Duration.zero);

      authSession.emit(_authenticatedState());
      await Future<void>.delayed(Duration.zero);

      expect(routeDispatcher.replacedStacks, hasLength(1));
      expect(
        routeDispatcher.replacedStacks.single.paths.last,
        equals(
          const AppRoute.sessionDetail(
            projectId: "project-2",
            projectName: null,
            sessionId: "session-2",
            sessionTitle: "Latest title",
            readOnly: false,
            bridgeId: null,
          ).buildPath(),
        ),
      );
    });

    test("same-target reopen still rebuilds stack", () async {
      await dispatcher.start();

      const request = NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-1",
        sessionTitle: "Weekly planning",
      );
      pushMessagingSource.emitOpen(request);
      pushMessagingSource.emitOpen(request);
      await Future<void>.delayed(Duration.zero);

      expect(routeDispatcher.replacedStacks, hasLength(2));
      expect(
        routeDispatcher.replacedStacks.map((stack) => stack.paths.last).toList(),
        everyElement(
          const AppRoute.sessionDetail(
            projectId: "project-1",
            projectName: null,
            sessionId: "session-1",
            sessionTitle: "Weekly planning",
            readOnly: false,
            bridgeId: null,
          ).buildPath(),
        ),
      );
    });

    test("late initial opens are ignored after dispose", () async {
      final initialOpenCompleter = Completer<NotificationOpenRequest?>();
      pushMessagingSource.initialOpenRequestFuture = initialOpenCompleter.future;

      final startFuture = dispatcher.start();
      await dispatcher.dispose();
      initialOpenCompleter.complete(
        const NotificationOpenRequest(
          projectId: "project-1",
          sessionId: "session-1",
          sessionTitle: "Late title",
        ),
      );
      await startFuture;

      expect(routeDispatcher.replacedStacks, isEmpty);
    });
  });
}

class FakeAuthSession({required AuthState initialState}) implements AuthSession {
  final BehaviorSubject<AuthState> _authStates = BehaviorSubject<AuthState>.seeded(initialState);

  @override
  ValueStream<AuthState> get authStateStream => _authStates.stream;

  @override
  AuthState get currentState => _authStates.value;

  void emit(AuthState state) => _authStates.add(state);

  Future<void> dispose() async {
    await _authStates.close();
  }

  @override
  Future<AuthUser?> getCurrentUser() async => null;

  @override
  Future<bool> hasLocallyValidSession() async => false;

  @override
  Future<void> invalidateAllSessions() async {}

  @override
  Future<void> logoutCurrentDevice() async {}

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<bool> restoreLocalSession() async => false;

  @override
  Future<AuthUser> loginWithEmail({required String email, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> loginWithApple({required String idToken, required String nonce}) async {
    throw UnimplementedError();
  }
}

class FakePushMessagingSource() implements PushMessagingSource {
  final StreamController<PushNotificationMessage> _foregroundMessageController =
      StreamController<PushNotificationMessage>.broadcast();
  final StreamController<NotificationOpenRequest> _notificationOpenedController =
      StreamController<NotificationOpenRequest>.broadcast();
  final StreamController<String> _tokenRefreshController = StreamController<String>.broadcast();
  NotificationOpenRequest? initialOpenRequest;
  Future<NotificationOpenRequest?>? initialOpenRequestFuture;

  @override
  DevicePlatform get devicePlatform => DevicePlatform.android;

  @override
  Stream<PushNotificationMessage> get foregroundMessageStream => _foregroundMessageController.stream;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> deleteToken() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationOpenRequest?> getInitialNotificationOpen() {
    return initialOpenRequestFuture ?? Future<NotificationOpenRequest?>.value(initialOpenRequest);
  }

  @override
  Stream<NotificationOpenRequest> get notificationOpenedStream => _notificationOpenedController.stream;

  @override
  Stream<String> get tokenRefreshStream => _tokenRefreshController.stream;

  void emitOpen(NotificationOpenRequest request) => _notificationOpenedController.add(request);

  Future<void> dispose() async {
    await _foregroundMessageController.close();
    await _notificationOpenedController.close();
    await _tokenRefreshController.close();
  }
}

class FakeLocalNotificationClient() implements LocalNotificationClient {
  final StreamController<NotificationOpenRequest> _notificationOpenedController =
      StreamController<NotificationOpenRequest>.broadcast();
  NotificationOpenRequest? initialOpenRequest;
  Future<NotificationOpenRequest?>? initialOpenRequestFuture;

  @override
  Future<void> cancelForSession({required String sessionId}) async {}

  @override
  Future<NotificationOpenRequest?> getInitialNotificationOpen() {
    return initialOpenRequestFuture ?? Future<NotificationOpenRequest?>.value(initialOpenRequest);
  }

  @override
  Future<void> initialize() async {}

  @override
  Stream<NotificationOpenRequest> get notificationOpenedStream => _notificationOpenedController.stream;

  void emitOpen(NotificationOpenRequest request) => _notificationOpenedController.add(request);

  @override
  Future<void> show({
    required String title,
    required String body,
    required NotificationCategory category,
    required String? sessionId,
    required String? projectId,
    required String? sessionTitle,
  }) async {}

  Future<void> dispose() async {
    await _notificationOpenedController.close();
  }
}

class RecordingRouteDispatcher() implements RouteDispatcher {
  final List<RouteStack> replacedStacks = <RouteStack>[];

  @override
  void replaceStack({required RouteStack stack}) {
    replacedStacks.add(stack);
  }
}

class FakeRouteSource() implements RouteSource {
  @override
  String? currentLocation;

  final BehaviorSubject<AppRouteDef?> _currentRoute = BehaviorSubject.seeded(null);

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => _currentRoute.stream;
}

AuthState _authenticatedState() {
  return const AuthState.authenticated(
    user: AuthUser(
      id: "user-1",
      provider: AuthProvider.github,
      providerUserId: "provider-user-1",
      providerUsername: "alex",
    ),
  );
}
