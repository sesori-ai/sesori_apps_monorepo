import "dart:async";
import "dart:io";

import "package:firebase_messaging/firebase_messaging.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "local_notification_manager.dart";

@lazySingleton
class NotificationService {
  final NotificationApiClient _apiClient;
  final NotificationPreferencesService _preferencesService;
  final LocalNotificationManager _localNotificationManager;
  final AuthSession _authSession;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String? _currentToken;
  bool _initialized = false;

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
    if (_initialized) return;
    _initialized = true;

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _localNotificationManager.initialize();

    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    _authSubscription = _authSession.authStateStream.listen(_onAuthStateChanged);

    final currentState = _authSession.currentState;
    if (currentState is AuthAuthenticated) {
      await registerCurrentToken();
    }
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

    final platform = Platform.isIOS ? "ios" : "android";
    await _apiClient.registerToken(token: token, platform: platform);
    _currentToken = token;
  }

  Future<void> unregisterCurrentToken() async {
    final token = _currentToken;
    if (token == null) return;

    await _apiClient.unregisterToken(token);
    _currentToken = null;
  }

  Future<void> _onAuthStateChanged(AuthState state) async {
    switch (state) {
      case AuthAuthenticated():
        try {
          await registerCurrentToken();
        } catch (error, stackTrace) {
          logw("Failed to register push token after auth", error, stackTrace);
        }
      case AuthUnauthenticated() || AuthAuthenticating() || AuthFailed():
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

    final platform = Platform.isIOS ? "ios" : "android";
    await _apiClient.registerToken(token: newToken, platform: platform);
    _currentToken = newToken;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final categoryKey = message.data["category"];
    if (categoryKey is! String) return;

    final category = _parseCategory(categoryKey);
    if (category == null) return;

    final isEnabled = await _preferencesService.isEnabled(category);
    if (!isEnabled) return;

    final title = message.notification?.title;
    final body = message.notification?.body;

    if (title == null || title.isEmpty || body == null || body.isEmpty) return;

    await _localNotificationManager.show(
      title: title,
      body: body,
      channelId: categoryKey,
    );
  }

  NotificationCategoryPreference? _parseCategory(String value) {
    return switch (value) {
      "ai_interaction" => NotificationCategoryPreference.aiInteraction,
      "session_message" => NotificationCategoryPreference.sessionMessage,
      "connection_status" => NotificationCategoryPreference.connectionStatus,
      "system_update" => NotificationCategoryPreference.systemUpdate,
      _ => null,
    };
  }

  @disposeMethod
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
  }
}
