import "dart:async";
import "dart:io";

import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "../routing/app_router.dart";
import "local_notification_manager.dart";

@lazySingleton
class NotificationService {
  final NotificationApiClient _apiClient;
  final NotificationPreferencesService _preferencesService;
  final LocalNotificationManager _localNotificationManager;
  final AuthSession _authSession;
  final CompositeSubscription _subscriptions = CompositeSubscription();
  String? _currentToken;
  String? _pendingSessionId;
  String? _pendingProjectId;
  void Function(String route) _goForTesting = appRouter.go;
  Future<void> Function(String route) _pushForTesting = (route) async {
    await appRouter.push<void>(route);
  };
  String Function() _currentPathProviderForTesting = () {
    return appRouter.routeInformationProvider.value.uri.path;
  };

  @visibleForTesting
  void Function(String route) get goForTesting => _goForTesting;

  @visibleForTesting
  set goForTesting(void Function(String route) value) => _goForTesting = value;

  @visibleForTesting
  Future<void> Function(String route) get pushForTesting => _pushForTesting;

  @visibleForTesting
  set pushForTesting(Future<void> Function(String route) value) => _pushForTesting = value;

  @visibleForTesting
  String Function() get currentPathProviderForTesting => _currentPathProviderForTesting;

  @visibleForTesting
  set currentPathProviderForTesting(String Function() value) => _currentPathProviderForTesting = value;

  @visibleForTesting
  String? get currentTokenForTesting => _currentToken;

  @visibleForTesting
  set currentTokenForTesting(String? token) => _currentToken = token;

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
    _subscriptions.add(FirebaseMessaging.onMessage.listen(onForegroundMessage));
    _subscriptions.add(_localNotificationManager.onNotificationTapped.listen(_onLocalNotificationTapped));

    // value stream that emits the current auth state too
    _subscriptions.add(_authSession.authStateStream.listen(onAuthStateChanged));

    // Handle notification taps when app is in background (not terminated).
    _subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTapped));

    // Handle notification tap that launched the app from terminated state.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _onNotificationTapped(initialMessage);
    }
  }

  void _onNotificationTapped(RemoteMessage message) {
    shared.NotificationData notificationData;
    try {
      notificationData = shared.NotificationData.fromJson(message.data);
    } catch (error, stackTrace) {
      logw("Failed to parse notification tap data", error, stackTrace);
      return;
    }

    final sessionId = notificationData.sessionId;
    final projectId = notificationData.projectId;
    if (sessionId == null) return;

    _navigateToSession(sessionId: sessionId, projectId: projectId);
  }

  @visibleForTesting
  void onNotificationTappedForTesting(RemoteMessage message) => _onNotificationTapped(message);

  void _onLocalNotificationTapped(NotificationTapEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == null) return;

    _navigateToSession(sessionId: sessionId, projectId: event.projectId);
  }

  @visibleForTesting
  void onLocalNotificationTappedForTesting(NotificationTapEvent event) => _onLocalNotificationTapped(event);

  void _navigateToSession({required String sessionId, required String? projectId}) {
    if (_authSession.currentState is! AuthAuthenticated) {
      _pendingSessionId = sessionId;
      _pendingProjectId = projectId;
      return;
    }

    _pushSessionRoute(sessionId: sessionId, projectId: projectId);
  }

  void _pushSessionRoute({required String sessionId, required String? projectId}) {
    if (projectId == null) {
      goForTesting(AppRouteDef.projects.path);
      return;
    }

    final sessionDetailPath = AppRoute.sessionDetail(
      projectId: projectId,
      sessionId: sessionId,
      sessionTitle: null,
      readOnly: false,
    ).buildPath();

    if (currentPathProviderForTesting() == sessionDetailPath) {
      return;
    }

    final sessionPath = AppRoute.sessions(projectId: projectId, projectName: null).buildPath();
    goForTesting(AppRouteDef.projects.path);
    unawaited(pushForTesting(sessionPath));
    unawaited(pushForTesting(sessionDetailPath));
  }

  Future<void> registerCurrentToken() async {
    if (Platform.isIOS || Platform.isMacOS) {
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
      platform: Platform.isIOS
          ? shared.DevicePlatform.ios
          : Platform.isMacOS
          ? shared.DevicePlatform.macos
          : shared.DevicePlatform.android,
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

  @visibleForTesting
  Future<void> onAuthStateChanged(AuthState state) async {
    logd("[FCM] Auth state changed: $state");
    switch (state) {
      case AuthAuthenticated():
        try {
          await registerCurrentToken();
        } catch (error, stackTrace) {
          logw("Failed to register push token after auth", error, stackTrace);
        }
        final pendingSessionId = _pendingSessionId;
        if (pendingSessionId != null) {
          _pendingSessionId = null;
          final pendingProjectId = _pendingProjectId;
          _pendingProjectId = null;
          _pushSessionRoute(sessionId: pendingSessionId, projectId: pendingProjectId);
        }
      case AuthUnauthenticated() || AuthFailed():
        try {
          await unregisterCurrentToken();
        } catch (error, stackTrace) {
          logw("Failed to unregister push token on auth change", error, stackTrace);
        }
      case AuthInitial() || AuthAuthenticating():
        break;
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
      platform: Platform.isIOS
          ? shared.DevicePlatform.ios
          : Platform.isMacOS
          ? shared.DevicePlatform.macos
          : shared.DevicePlatform.android,
    );
    await _apiClient.registerToken(request);
    _currentToken = newToken;
  }

  @visibleForTesting
  Future<void> onForegroundMessage(RemoteMessage message) async {
    shared.NotificationData notificationData;
    try {
      notificationData = shared.NotificationData.fromJson(message.data);
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
      sessionId: notificationData.sessionId,
      projectId: notificationData.projectId,
    );
  }

  @disposeMethod
  Future<void> dispose() async {
    _disposed = true;
    await _subscriptions.dispose();
  }
}
