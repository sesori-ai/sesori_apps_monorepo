import "dart:io";

import "package:firebase_messaging/firebase_messaging.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "local_notification_manager.dart";

@lazySingleton
class NotificationService {
  final NotificationApiClient _apiClient;
  final NotificationPreferencesService _preferencesService;
  final LocalNotificationManager _localNotificationManager;
  final AuthSession _authSession;
  final CompositeSubscription _subscriptions = CompositeSubscription();
  String? _currentToken;
  bool _initialized = false;
  bool _disposed = false;

  NotificationService(
    NotificationApiClient apiClient,
    NotificationPreferencesService preferencesService,
    LocalNotificationManager localNotificationManager,
    AuthSession authSession,
  ) : _apiClient = apiClient,
      _preferencesService = preferencesService,
      _localNotificationManager = localNotificationManager,
      _authSession = authSession;

  Future<void> initialize() async {
    if (_disposed) {
      logw("NotificationService.initialize() called after dispose");
      return;
    }
    if (_initialized) return;
    _initialized = true;

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _localNotificationManager.initialize();

    _subscriptions.add(FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh));
    _subscriptions.add(FirebaseMessaging.onMessage.listen(_onForegroundMessage));

    // value stream that emits the current auth state too
    _subscriptions.add(_authSession.authStateStream.listen(_onAuthStateChanged));

    // Handle notification taps when app is in background (not terminated).
    _subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTapped));

    // Handle notification tap that launched the app from terminated state.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _onNotificationTapped(initialMessage);
    }
  }

  void _onNotificationTapped(RemoteMessage message) {
    // TODO: handle event — navigate to the relevant screen based on message.data
    // e.g. if message.data['sessionId'] is present, navigate to session detail
  }

  Future<void> registerCurrentToken() async {
    if (Platform.isIOS) {
      for (var i = 0; i < 5; i++) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty || token == _currentToken) return;

    final request = RegisterTokenRequest(
      token: token,
      platform: Platform.isIOS ? DevicePlatform.ios : DevicePlatform.android,
    );
    logd("[FCM] Registering push token: ...${token.takeLast(6)}");
    await _apiClient.registerToken(request);
    _currentToken = token;
  }

  Future<void> unregisterCurrentToken() async {
    final token = _currentToken;
    if (token == null) return;

    await _apiClient.unregisterToken(token);
    _currentToken = null;
  }

  Future<void> _onAuthStateChanged(AuthState state) async {
    logd("[FCM] Auth state changed: $state");
    switch (state) {
      case AuthAuthenticated():
        try {
          await registerCurrentToken();
        } catch (error, stackTrace) {
          logw("Failed to register push token after auth", error, stackTrace);
        }
      case AuthInitial() || AuthUnauthenticated() || AuthAuthenticating() || AuthFailed():
        try {
          await unregisterCurrentToken();
        } catch (error, stackTrace) {
          logw("Failed to unregister push token on auth change", error, stackTrace);
        }
    }
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final oldToken = _currentToken;

    if (oldToken != null && oldToken != newToken) {
      try {
        await _apiClient.unregisterToken(oldToken);
      } catch (error, stackTrace) {
        logw("Failed to unregister old push token", error, stackTrace);
      }
    }

    if (_authSession.currentState is! AuthAuthenticated) return;

    final request = RegisterTokenRequest(
      token: newToken,
      platform: Platform.isIOS ? DevicePlatform.ios : DevicePlatform.android,
    );
    await _apiClient.registerToken(request);
    _currentToken = newToken;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    NotificationData notificationData;
    try {
      notificationData = NotificationData.fromJson(message.data);
    } catch (error, stackTrace) {
      logw("Failed to parse notification data", error, stackTrace);
      return;
    }

    final category = notificationData.category;

    final isEnabled = await _preferencesService.isEnabled(category);
    if (!isEnabled) return;

    final title = message.notification?.title;
    final body = message.notification?.body;

    if (title == null || title.isEmpty || body == null || body.isEmpty) return;

    await _localNotificationManager.show(
      title: title,
      body: body,
      category: category,
    );
  }

  @disposeMethod
  Future<void> dispose() async {
    _disposed = true;
    await _subscriptions.dispose();
  }
}
