import "dart:async";
import "dart:io";

import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

@LazySingleton(as: PushMessagingSource)
class FirebasePushMessagingSource implements PushMessagingSource {
  final FirebaseMessaging _messaging;
  final bool Function() _isApplePlatform;
  final Future<void> Function(Duration) _delay;
  final StreamController<PushNotificationMessage> _foregroundMessageController =
      StreamController<PushNotificationMessage>.broadcast();
  final StreamController<NotificationOpenRequest> _notificationOpenedController =
      StreamController<NotificationOpenRequest>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _notificationOpenedSubscription;
  Future<void>? _initializeFuture;
  NotificationOpenRequest? _initialNotificationOpen;
  bool _initialNotificationOpenConsumed = false;
  bool _disposed = false;

  FirebasePushMessagingSource()
    : _messaging = FirebaseMessaging.instance,
      _isApplePlatform = _defaultIsApplePlatform,
      _delay = Future<void>.delayed;

  @visibleForTesting
  FirebasePushMessagingSource.test({
    required FirebaseMessaging messaging,
    bool Function()? isApplePlatform,
    Future<void> Function(Duration)? delay,
  }) : _messaging = messaging,
       _isApplePlatform = isApplePlatform ?? _defaultIsApplePlatform,
       _delay = delay ?? Future<void>.delayed;

  static bool _defaultIsApplePlatform() => Platform.isIOS || Platform.isMacOS;

  @override
  DevicePlatform get devicePlatform {
    if (Platform.isIOS) {
      return DevicePlatform.ios;
    }
    if (Platform.isMacOS) {
      return DevicePlatform.macos;
    }
    return DevicePlatform.android;
  }

  @override
  Stream<PushNotificationMessage> get foregroundMessageStream =>
      _foregroundMessageController.stream;

  @override
  Stream<NotificationOpenRequest> get notificationOpenedStream =>
      _notificationOpenedController.stream;

  @override
  Stream<String> get tokenRefreshStream => _messaging.onTokenRefresh;

  @override
  Future<void> initialize() async {
    if (_disposed) {
      logw("FirebasePushMessagingSource.initialize() called after dispose");
      return;
    }
    _initializeFuture ??= _doInitialize();
    await _initializeFuture;
  }

  Future<void> _doInitialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _onForegroundMessage,
    );
    _notificationOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _onNotificationOpened,
    );

    _initialNotificationOpen = notificationOpenFromMessageForTesting(
      message: await _messaging.getInitialMessage(),
    );
  }

  @override
  Future<String?> getToken() async {
    if (_isApplePlatform()) {
      var apnsToken = await _messaging.getAPNSToken();
      for (var i = 0; i < 5; i++) {
        if (apnsToken != null) {
          break;
        }
        await _delay(const Duration(seconds: 1));
        apnsToken = await _messaging.getAPNSToken();
      }
      if (apnsToken == null) {
        return null;
      }
    }

    return _messaging.getToken();
  }

  @override
  Future<NotificationOpenRequest?> getInitialNotificationOpen() async {
    if (_initialNotificationOpenConsumed) {
      return null;
    }

    _initialNotificationOpenConsumed = true;
    return _initialNotificationOpen;
  }

  @visibleForTesting
  NotificationOpenRequest? notificationOpenFromMessageForTesting({
    required RemoteMessage? message,
  }) {
    if (message == null) {
      return null;
    }

    NotificationData notificationData;
    try {
      notificationData = NotificationData.fromJson(message.data);
    } catch (error, stackTrace) {
      logw("Failed to parse push notification open payload", error, stackTrace);
      return null;
    }

    final sessionId = notificationData.sessionId;
    final projectId = notificationData.projectId;
    if (sessionId == null || projectId == null) {
      return null;
    }

    return NotificationOpenRequest(
      projectId: projectId,
      sessionId: sessionId,
      sessionTitle: message.notification?.title,
    );
  }

  @visibleForTesting
  PushNotificationMessage pushNotificationMessageFromRemoteMessageForTesting({
    required RemoteMessage message,
  }) {
    return PushNotificationMessage(
      title: message.notification?.title,
      body: message.notification?.body,
      data: Map<String, dynamic>.from(message.data),
    );
  }

  void _onForegroundMessage(RemoteMessage message) {
    _foregroundMessageController.add(
      pushNotificationMessageFromRemoteMessageForTesting(message: message),
    );
  }

  void _onNotificationOpened(RemoteMessage message) {
    final openRequest = notificationOpenFromMessageForTesting(message: message);
    if (openRequest != null) {
      _notificationOpenedController.add(openRequest);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _foregroundMessageSubscription?.cancel();
    await _notificationOpenedSubscription?.cancel();
    await _foregroundMessageController.close();
    await _notificationOpenedController.close();
    _foregroundMessageSubscription = null;
    _notificationOpenedSubscription = null;
  }
}
