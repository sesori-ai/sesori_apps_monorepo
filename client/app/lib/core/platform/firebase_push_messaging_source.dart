import "dart:async";
import "dart:io";

import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../di/firebase_register_module.dart";
import "../sesori_test_mode.dart";
import "firebase/firebase_messaging_static_adapter.dart";

@firebaseEnabledEnvironment
@LazySingleton(as: PushMessagingSource)
class FirebasePushMessagingSource implements PushMessagingSource {
  final FirebaseMessaging _messaging;
  final FirebaseMessagingStaticAdapter _staticAdapter;
  final bool Function() _isApplePlatform;

  /// False under [sesoriTestMode], whose unattended drivers cannot answer the
  /// native prompt.
  final bool _requestsPermission;
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

  new({
    required FirebaseMessaging messaging,
    required FirebaseMessagingStaticAdapter staticAdapter,
  }) : _messaging = messaging,
       _staticAdapter = staticAdapter,
       _isApplePlatform = _defaultIsApplePlatform,
       _requestsPermission = !sesoriTestMode,
       _delay = Future<void>.delayed;

  @visibleForTesting
  new test({
    required FirebaseMessaging messaging,
    FirebaseMessagingStaticAdapter staticAdapter = const FirebaseMessagingStaticAdapter.disabled(),
    bool Function()? isApplePlatform,
    bool requestsPermission = true,
    Future<void> Function(Duration)? delay,
  }) : _messaging = messaging,
       _staticAdapter = staticAdapter,
       _isApplePlatform = isApplePlatform ?? _defaultIsApplePlatform,
       _requestsPermission = requestsPermission,
       _delay = delay ?? Future<void>.delayed;

  static bool _defaultIsApplePlatform() => Platform.isIOS;

  @override
  DevicePlatform get devicePlatform => Platform.isIOS ? DevicePlatform.ios : DevicePlatform.android;

  @override
  Stream<PushNotificationMessage> get foregroundMessageStream => _foregroundMessageController.stream;

  @override
  Stream<NotificationOpenRequest> get notificationOpenedStream => _notificationOpenedController.stream;

  // firebase_messaging 17 deprecates the token API in favour of
  // register()/onRegistered; migrating changes the push-token lifecycle and
  // is done separately from the dependency bump.
  @override
  // ignore: deprecated_member_use
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
    if (_requestsPermission) {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    }
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    _foregroundMessageSubscription = _staticAdapter.foregroundMessageStream.listen(
      _onForegroundMessage,
    );
    _notificationOpenedSubscription = _staticAdapter.notificationOpenedStream.listen(
      _onNotificationOpened,
    );

    _initialNotificationOpen = notificationOpenFromMessage(
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

    // ignore: deprecated_member_use
    return await _messaging.getToken();
  }

  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Future<NotificationOpenRequest?> getInitialNotificationOpen() async {
    if (_initialNotificationOpenConsumed) {
      return null;
    }

    _initialNotificationOpenConsumed = true;
    return _initialNotificationOpen;
  }

  @visibleForTesting
  NotificationOpenRequest? notificationOpenFromMessage({
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
      accountId: null,
      bridgeId: notificationData.bridgeId,
    );
  }

  @visibleForTesting
  PushNotificationMessage pushNotificationMessageFromRemoteMessage({
    required RemoteMessage message,
  }) {
    return PushNotificationMessage(
      title: message.notification?.title,
      body: message.notification?.body,
      data: Map.of(message.data),
    );
  }

  void _onForegroundMessage(RemoteMessage message) {
    _foregroundMessageController.add(
      pushNotificationMessageFromRemoteMessage(message: message),
    );
  }

  void _onNotificationOpened(RemoteMessage message) {
    final openRequest = notificationOpenFromMessage(message: message);
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
