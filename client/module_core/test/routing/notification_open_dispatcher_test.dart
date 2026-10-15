import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/platform/local_notification_client.dart";
import "package:sesori_dart_core/src/platform/notification_open_request.dart";
import "package:sesori_dart_core/src/platform/push_messaging_source.dart";
import "package:sesori_dart_core/src/platform/push_notification_message.dart";
import "package:sesori_dart_core/src/platform/route_dispatcher.dart";
import "package:sesori_dart_core/src/platform/route_source.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_dart_core/src/routing/computer_switch_dispatcher.dart";
import "package:sesori_dart_core/src/routing/notification_open_dispatcher.dart";
import "package:sesori_dart_core/src/services/selected_computer_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  group("NotificationOpenDispatcher", () {
    late FakeAuthSession authSession;
    late FakePushMessagingSource pushMessagingSource;
    late FakeLocalNotificationClient localNotificationClient;
    late RecordingRouteDispatcher routeDispatcher;
    late FakeRouteSource routeSource;
    late RecordingSelectedComputerService selectedComputerService;
    late NotificationOpenDispatcher dispatcher;

    setUp(() {
      authSession = FakeAuthSession(initialState: _authenticatedState());
      pushMessagingSource = FakePushMessagingSource();
      localNotificationClient = FakeLocalNotificationClient();
      routeDispatcher = RecordingRouteDispatcher();
      routeSource = FakeRouteSource();
      selectedComputerService = RecordingSelectedComputerService(routeDispatcher: routeDispatcher)
        ..target = "br_current";
      dispatcher = NotificationOpenDispatcher(
        authSession: authSession,
        pushMessagingSource: pushMessagingSource,
        localNotificationClient: localNotificationClient,
        routeDispatcher: routeDispatcher,
        routeSource: routeSource,
        selectedComputerService: selectedComputerService,
        computerSwitchDispatcher: ComputerSwitchDispatcher(
          selectedComputerService: selectedComputerService,
          routeDispatcher: routeDispatcher,
        ),
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
        accountId: null,
        bridgeId: null,
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
            fromLaunch: false,
          ).buildPath(),
        ]),
      );
    });

    test("a push for the current computer opens without switching", () async {
      pushMessagingSource.initialOpenRequest = const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-1",
        sessionTitle: "Weekly planning",
        accountId: null,
        bridgeId: "br_current",
      );

      await dispatcher.start();
      await Future<void>.delayed(Duration.zero);

      expect(selectedComputerService.selections, isEmpty);
      expect(routeDispatcher.replacedStacks.single.paths.last, contains("session-1"));
    });

    test("a push for another computer switches to it, then opens the session", () async {
      // The session on top has the same id on the previous computer; it must
      // not keep the app there.
      routeSource.currentLocation = "/projects/project-1/sessions/session-1";
      pushMessagingSource.initialOpenRequest = const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-1",
        sessionTitle: "Weekly planning",
        accountId: null,
        bridgeId: "br_other",
      );

      await dispatcher.start();
      await Future<void>.delayed(Duration.zero);

      expect(selectedComputerService.selections, [(bridgeId: "br_other", source: ComputerSwitchSource.notification)]);
      // The switch lands on Projects before it retargets, and the session
      // stack is built only after the retarget.
      expect(selectedComputerService.stacksBeforeSelect, [1]);
      expect(routeDispatcher.replacedStacks, hasLength(2));
      expect(routeDispatcher.replacedStacks.first.paths, [const AppRoute.projects().buildPath()]);
      expect(
        routeDispatcher.replacedStacks.last.paths.last,
        const AppRoute.sessionDetail(
          projectId: "project-1",
          projectName: null,
          sessionId: "session-1",
          sessionTitle: "Weekly planning",
          readOnly: false,
          fromLaunch: false,
        ).buildPath(),
      );
    });

    test("a push without a computer id opens on the current computer", () async {
      pushMessagingSource.initialOpenRequest = const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-1",
        sessionTitle: "Weekly planning",
        accountId: null,
        bridgeId: null,
      );

      await dispatcher.start();

      expect(selectedComputerService.selections, isEmpty);
      expect(routeDispatcher.replacedStacks, hasLength(1));
    });

    test("leaves the stack alone when that session detail is already on top", () async {
      // Display-only query parameters differ from what the notification would
      // build; they must not defeat the match.
      routeSource.currentLocation = "/projects/project-1/sessions/session-1?readOnly=false&title=Renamed";
      pushMessagingSource.initialOpenRequest = const NotificationOpenRequest(
        projectId: "project-1",
        sessionId: "session-1",
        sessionTitle: "Weekly planning",
        accountId: null,
        bridgeId: null,
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
        accountId: null,
        bridgeId: null,
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
        accountId: null,
        bridgeId: null,
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
        accountId: null,
        bridgeId: null,
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
          accountId: null,
          bridgeId: null,
        ),
      );
      await startFuture;

      localNotificationClient.emitOpen(
        const NotificationOpenRequest(
          projectId: "project-2",
          sessionId: "session-2",
          sessionTitle: "Latest title",
          accountId: null,
          bridgeId: null,
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
            fromLaunch: false,
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
        accountId: null,
        bridgeId: null,
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
            fromLaunch: false,
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
          accountId: null,
          bridgeId: null,
        ),
      );
      await startFuture;

      expect(routeDispatcher.replacedStacks, isEmpty);
    });
  });
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
  Future<void> cancelAll() async {}

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
    required String? accountId,
    required String? bridgeId,
  }) async {}

  @override
  Future<void> dispose() async {
    await _notificationOpenedController.close();
  }
}

class RecordingRouteDispatcher() implements RouteDispatcher {
  final List<RouteStack> replacedStacks = <RouteStack>[];

  @override
  void dismissPopups() {}

  @override
  void replaceStack({required RouteStack stack}) {
    replacedStacks.add(stack);
  }
}

class RecordingSelectedComputerService({required final RecordingRouteDispatcher _routeDispatcher})
    implements SelectedComputerService {
  String? target;
  final List<({String bridgeId, ComputerSwitchSource source})> selections = [];
  final List<int> stacksBeforeSelect = [];

  @override
  Future<String?> targetBridgeId() async => target;

  @override
  Future<void> select({required String bridgeId, required ComputerSwitchSource source}) async {
    stacksBeforeSelect.add(_routeDispatcher.replacedStacks.length);
    selections.add((bridgeId: bridgeId, source: source));
    target = bridgeId;
  }

  @override
  Future<void> ensureInitialTarget({required String? localBridgeId}) async {}

  @override
  Future<void> followLocalComputer({required String bridgeId}) async {}

  @override
  Future<String?> replacementAfterRemoving({required String bridgeId, required bool wasCurrent}) async => null;

  @override
  void forgetPick() {}
}

class FakeRouteSource() implements RouteSource {
  @override
  String? currentLocation;

  final BehaviorSubject<AppRouteDef?> _currentRoute = BehaviorSubject.seeded(null);

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => _currentRoute.stream;

  @override
  Stream<bool> get projectPageVisibility => currentRouteStream.map((route) => route == AppRouteDef.projects);
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
