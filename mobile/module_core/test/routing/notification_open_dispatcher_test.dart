import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/platform/local_notification_client.dart";
import "package:sesori_dart_core/src/platform/notification_open_request.dart";
import "package:sesori_dart_core/src/platform/push_messaging_source.dart";
import "package:sesori_dart_core/src/platform/push_notification_message.dart";
import "package:sesori_dart_core/src/platform/route_dispatcher.dart";
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
    late NotificationOpenDispatcher dispatcher;

    setUp(() {
      authSession = FakeAuthSession(initialState: _authenticatedState());
      pushMessagingSource = FakePushMessagingSource();
      localNotificationClient = FakeLocalNotificationClient();
      routeDispatcher = RecordingRouteDispatcher();
      dispatcher = NotificationOpenDispatcher(
        authSession: authSession,
        pushMessagingSource: pushMessagingSource,
        localNotificationClient: localNotificationClient,
        routeDispatcher: routeDispatcher,
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
          const AppRoute.sessions(projectId: "project-1", projectName: null).buildPath(),
          const AppRoute.sessionDetail(
            projectId: "project-1",
            sessionId: "session-1",
            sessionTitle: "Weekly planning",
            readOnly: false,
          ).buildPath(),
        ]),
      );
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
            sessionId: "session-2",
            sessionTitle: "Latest title",
            readOnly: false,
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
            sessionId: "session-1",
            sessionTitle: "Weekly planning",
            readOnly: false,
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

class FakeAuthSession implements AuthSession {
  final BehaviorSubject<AuthState> _authStates;

  FakeAuthSession({required AuthState initialState}) : _authStates = BehaviorSubject<AuthState>.seeded(initialState);

  @override
  ValueStream<AuthState> get authStateStream => _authStates.stream;

  @override
  AuthState get currentState => _authStates.value;

  void emit(AuthState state) => _authStates.add(state);

  Future<void> dispose() async => _authStates.close();

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
  Future<AuthUser> loginWithEmail({required String email, required String password}) async {
    throw UnimplementedError();
  }
}

class FakePushMessagingSource implements PushMessagingSource {
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

class FakeLocalNotificationClient implements LocalNotificationClient {
  final StreamController<NotificationOpenRequest> _notificationOpenedController =
      StreamController<NotificationOpenRequest>.broadcast();
  NotificationOpenRequest? initialOpenRequest;
  Future<NotificationOpenRequest?>? initialOpenRequestFuture;

  @override
  Future<void> cancelForSession({required String sessionId, required NotificationCategory category}) async {}

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

  Future<void> dispose() async => _notificationOpenedController.close();
}

class RecordingRouteDispatcher implements RouteDispatcher {
  final List<RouteStack> replacedStacks = <RouteStack>[];

  @override
  void replaceStack({required RouteStack stack}) {
    replacedStacks.add(stack);
  }
}

AuthState _authenticatedState() {
  return const AuthState.authenticated(
    user: AuthUser(
      id: "user-1",
      provider: "github",
      providerUserId: "provider-user-1",
      providerUsername: "alex",
    ),
  );
}
