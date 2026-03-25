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
    test("passes sessionId to show() when message contains sessionId", () async {
      when(() => preferencesService.isEnabled(any())).thenAnswer((_) async => true);
      when(
        () => localNotificationManager.show(
          title: any(named: "title"),
          body: any(named: "body"),
          category: any(named: "category"),
          sessionId: any(named: "sessionId"),
        ),
      ).thenAnswer((_) async {});

      const sessionId = "ses_abc";
      const message = RemoteMessage(
        data: {
          "category": "ai_interaction",
          "eventType": "question_asked",
          "sessionId": sessionId,
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
        ),
      ).called(1);
    });

    test("calls show() without sessionId when message has no sessionId", () async {
      when(() => preferencesService.isEnabled(any())).thenAnswer((_) async => true);
      when(
        () => localNotificationManager.show(
          title: any(named: "title"),
          body: any(named: "body"),
          category: any(named: "category"),
          sessionId: any(named: "sessionId"),
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
        ),
      ).called(1);
    });
  });
}
