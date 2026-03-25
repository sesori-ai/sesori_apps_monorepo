import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/local_notification_manager.dart";
import "package:sesori_mobile/core/platform/notification_service.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

class MockNotificationApiClient extends Mock implements NotificationApiClient {}

class MockNotificationPreferencesService extends Mock implements NotificationPreferencesService {}

class MockLocalNotificationManager extends Mock implements LocalNotificationManager {}

void main() {
  setUpAll(() {
    registerFallbackValue(NotificationCategory.aiInteraction);
  });
  late MockNotificationApiClient apiClient;
  late MockNotificationPreferencesService preferencesService;
  late MockLocalNotificationManager localNotificationManager;
  late MockAuthSession authSession;
  late NotificationService service;

  setUp(() {
    apiClient = MockNotificationApiClient();
    preferencesService = MockNotificationPreferencesService();
    localNotificationManager = MockLocalNotificationManager();
    authSession = MockAuthSession();

    service = NotificationService(
      apiClient,
      preferencesService,
      localNotificationManager,
      authSession,
    );

    when(() => authSession.currentState).thenReturn(
      const AuthState.authenticated(
        user: AuthUser(
          id: "user-1",
          provider: "github",
          providerUserId: "provider-user-1",
          providerUsername: "test-user",
        ),
      ),
    );
  });

  group("notification tap navigation", () {
    RemoteMessage buildTapMessage({required String? sessionId, required String? projectId}) {
      return RemoteMessage(
        data: {
          "category": "ai_interaction",
          "eventType": "question_asked",
          "sessionId": sessionId,
          "projectId": projectId,
        },
      );
    }

    test("firebase tap with sessionId and projectId builds full navigation stack", () {
      final goCalls = <String>[];
      final pushCalls = <String>[];

      service.goForTesting = goCalls.add;
      service.pushForTesting = (route) async {
        pushCalls.add(route);
      };
      service.currentPathProviderForTesting = () => "/projects";

      service.onNotificationTappedForTesting(
        buildTapMessage(sessionId: "ses_1", projectId: "proj_1"),
      );

      expect(goCalls, equals([AppRoute.projects.path]));
      expect(
        pushCalls,
        equals([
          AppRoute.sessions.buildPath(pathParams: {"projectId": "proj_1"}),
          AppRoute.sessionDetail.buildPath(pathParams: {"projectId": "proj_1", "sessionId": "ses_1"}),
        ]),
      );
    });

    test("firebase tap with sessionId and no projectId navigates to project list only", () {
      final goCalls = <String>[];
      final pushCalls = <String>[];

      service.goForTesting = goCalls.add;
      service.pushForTesting = (route) async {
        pushCalls.add(route);
      };
      service.currentPathProviderForTesting = () => "/projects";

      service.onNotificationTappedForTesting(
        buildTapMessage(sessionId: "ses_1", projectId: null),
      );

      expect(goCalls, equals([AppRoute.projects.path]));
      expect(pushCalls, isEmpty);
    });

    test("firebase tap with no sessionId does not navigate", () {
      final goCalls = <String>[];
      final pushCalls = <String>[];

      service.goForTesting = goCalls.add;
      service.pushForTesting = (route) async {
        pushCalls.add(route);
      };
      service.currentPathProviderForTesting = () => "/projects";

      service.onNotificationTappedForTesting(
        buildTapMessage(sessionId: null, projectId: "proj_1"),
      );

      expect(goCalls, isEmpty);
      expect(pushCalls, isEmpty);
    });

    test("local notification tap uses same navigation path as firebase tap", () {
      final goCalls = <String>[];
      final pushCalls = <String>[];

      service.goForTesting = goCalls.add;
      service.pushForTesting = (route) async {
        pushCalls.add(route);
      };
      service.currentPathProviderForTesting = () => "/projects";

      service.onLocalNotificationTappedForTesting(
        const NotificationTapEvent(sessionId: "ses_local", projectId: "proj_local"),
      );

      expect(goCalls, equals([AppRoute.projects.path]));
      expect(
        pushCalls,
        equals([
          AppRoute.sessions.buildPath(pathParams: {"projectId": "proj_local"}),
          AppRoute.sessionDetail.buildPath(pathParams: {"projectId": "proj_local", "sessionId": "ses_local"}),
        ]),
      );
    });

    test("tap while unauthenticated is deferred and replayed after authentication", () async {
      final goCalls = <String>[];
      final pushCalls = <String>[];

      when(() => authSession.currentState).thenReturn(const AuthState.unauthenticated());

      service.goForTesting = goCalls.add;
      service.pushForTesting = (route) async {
        pushCalls.add(route);
      };
      service.currentPathProviderForTesting = () => "/projects";

      service.onNotificationTappedForTesting(
        buildTapMessage(sessionId: "ses_pending", projectId: "proj_pending"),
      );

      expect(goCalls, isEmpty);
      expect(pushCalls, isEmpty);

      await service.onAuthStateChanged(
        const AuthState.authenticated(
          user: AuthUser(
            id: "user-1",
            provider: "github",
            providerUserId: "provider-user-1",
            providerUsername: "test-user",
          ),
        ),
      );

      expect(goCalls, equals([AppRoute.projects.path]));
      expect(
        pushCalls,
        equals([
          AppRoute.sessions.buildPath(pathParams: {"projectId": "proj_pending"}),
          AppRoute.sessionDetail.buildPath(pathParams: {"projectId": "proj_pending", "sessionId": "ses_pending"}),
        ]),
      );
    });

    test("tap while already on target session does not navigate again", () {
      final goCalls = <String>[];
      final pushCalls = <String>[];

      final targetPath = AppRoute.sessionDetail.buildPath(
        pathParams: {"projectId": "proj_1", "sessionId": "ses_1"},
      );

      service.goForTesting = goCalls.add;
      service.pushForTesting = (route) async {
        pushCalls.add(route);
      };
      service.currentPathProviderForTesting = () => targetPath;

      service.onNotificationTappedForTesting(
        buildTapMessage(sessionId: "ses_1", projectId: "proj_1"),
      );

      expect(goCalls, isEmpty);
      expect(pushCalls, isEmpty);
    });
  });

  group("onAuthStateChanged", () {
    test("AuthUnauthenticated unregisters the current token", () async {
      const token = "existing-fcm-token";
      service.currentTokenForTesting = token;
      when(() => apiClient.unregisterToken(token)).thenAnswer((_) async {});

      await service.onAuthStateChanged(const AuthState.unauthenticated());

      verify(() => apiClient.unregisterToken(token)).called(1);
    });

    test("AuthUnauthenticated with no token is a no-op", () async {
      await service.onAuthStateChanged(const AuthState.unauthenticated());

      verifyZeroInteractions(apiClient);
    });

    test("AuthFailed unregisters the current token", () async {
      const token = "existing-fcm-token";
      service.currentTokenForTesting = token;
      when(() => apiClient.unregisterToken(token)).thenAnswer((_) async {});

      await service.onAuthStateChanged(const AuthState.failed(error: "session expired"));

      verify(() => apiClient.unregisterToken(token)).called(1);
    });

    test("AuthInitial does not unregister or register", () async {
      service.currentTokenForTesting = "existing-token";

      await service.onAuthStateChanged(const AuthState.initial());

      verifyZeroInteractions(apiClient);
    });

    test("AuthAuthenticating does not unregister or register", () async {
      service.currentTokenForTesting = "existing-token";

      await service.onAuthStateChanged(const AuthState.authenticating());

      verifyZeroInteractions(apiClient);
    });

    test("AuthUnauthenticated clears the current token after unregister", () async {
      const token = "existing-fcm-token";
      service.currentTokenForTesting = token;
      when(() => apiClient.unregisterToken(token)).thenAnswer((_) async {});

      await service.onAuthStateChanged(const AuthState.unauthenticated());

      // Second call should be a no-op since token was cleared.
      await service.onAuthStateChanged(const AuthState.unauthenticated());

      verify(() => apiClient.unregisterToken(token)).called(1);
    });
  });

  group("unregisterCurrentToken", () {
    test("calls API and clears token when token exists", () async {
      const token = "fcm-token";
      service.currentTokenForTesting = token;
      when(() => apiClient.unregisterToken(token)).thenAnswer((_) async {});

      await service.unregisterCurrentToken();

      verify(() => apiClient.unregisterToken(token)).called(1);
    });

    test("is a no-op when no current token", () async {
      await service.unregisterCurrentToken();

      verifyZeroInteractions(apiClient);
    });
  });

  group("onForegroundMessage", () {
    test("passes sessionId and projectId to show() when message contains them", () async {
      when(() => preferencesService.isEnabled(any())).thenAnswer((_) async => true);
      when(
        () => localNotificationManager.show(
          title: any(named: "title"),
          body: any(named: "body"),
          category: any(named: "category"),
          sessionId: any(named: "sessionId"),
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) async {});

      const sessionId = "ses_abc";
      const projectId = "proj_xyz";
      const message = RemoteMessage(
        data: {
          "category": "ai_interaction",
          "eventType": "question_asked",
          "sessionId": sessionId,
          "projectId": projectId,
        },
        notification: RemoteNotification(
          title: "Test Title",
          body: "Test Body",
        ),
      );

      await service.onForegroundMessage(message);

      verify(
        () => localNotificationManager.show(
          title: "Test Title",
          body: "Test Body",
          category: NotificationCategory.aiInteraction,
          sessionId: sessionId,
          projectId: projectId,
        ),
      ).called(1);
    });

    test("calls show() without sessionId or projectId when message has neither", () async {
      when(() => preferencesService.isEnabled(any())).thenAnswer((_) async => true);
      when(
        () => localNotificationManager.show(
          title: any(named: "title"),
          body: any(named: "body"),
          category: any(named: "category"),
          sessionId: any(named: "sessionId"),
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) async {});

      const message = RemoteMessage(
        data: {
          "category": "session_message",
          "eventType": null,
        },
        notification: RemoteNotification(
          title: "Test Title",
          body: "Test Body",
        ),
      );

      await service.onForegroundMessage(message);

      verify(
        () => localNotificationManager.show(
          title: "Test Title",
          body: "Test Body",
          category: NotificationCategory.sessionMessage,
          sessionId: null,
          projectId: null,
        ),
      ).called(1);
    });
  });
}
