import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "notification_tap_event.dart";

extension on NotificationImportance {
  Importance toLocalNotificationImportance() {
    return switch (this) {
      .high => .high,
      .max => .max,
      .defaultImportance => .defaultImportance,
      .low => .low,
      .min => .min,
      .none => .none,
      .unspecified => .unspecified,
    };
  }
}

@LazySingleton(as: LocalNotificationClient)
class FlutterLocalNotificationClient implements LocalNotificationClient {
  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<NotificationOpenRequest> _notificationOpenedController =
      StreamController<NotificationOpenRequest>.broadcast();

  NotificationOpenRequest? _initialNotificationOpen;
  bool _initialNotificationOpenConsumed = false;
  bool _initialized = false;

  FlutterLocalNotificationClient({required FlutterLocalNotificationsPlugin plugin}) : _plugin = plugin;

  @override
  Stream<NotificationOpenRequest> get notificationOpenedStream => _notificationOpenedController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    _initialNotificationOpen = _notificationOpenFromPayload(
      payload: launchDetails?.didNotificationLaunchApp == true ? launchDetails?.notificationResponse?.payload : null,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      for (final channel in NotificationCategory.values.where((e) => e != .unknown)) {
        await androidPlugin?.createNotificationChannel(
          AndroidNotificationChannel(
            channel.id,
            channel.displayName,
            description: channel.description,
            importance: channel.importance.toLocalNotificationImportance(),
          ),
        );
      }
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings("@drawable/ic_notification"),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
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
  void handleNotificationResponseForTesting(NotificationResponse response) => _onNotificationResponse(response);

  @visibleForTesting
  NotificationOpenRequest? notificationOpenFromPayloadForTesting({
    required String? payload,
  }) {
    return _notificationOpenFromPayload(payload: payload);
  }

  NotificationOpenRequest? _notificationOpenFromPayload({required String? payload}) {
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final tapEvent = NotificationTapEvent.fromJson(jsonDecodeMap(payload));
      final sessionId = tapEvent.sessionId;
      final projectId = tapEvent.projectId;
      if (sessionId == null || projectId == null) {
        return null;
      }

      return NotificationOpenRequest(
        projectId: projectId,
        sessionId: sessionId,
        sessionTitle: tapEvent.sessionTitle,
      );
    } catch (error, stackTrace) {
      logw("Failed to parse local notification payload", error, stackTrace);
      return null;
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final openRequest = _notificationOpenFromPayload(payload: response.payload);
    if (openRequest != null) {
      _notificationOpenedController.add(openRequest);
    }
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    required NotificationCategory category,
    required String? sessionId,
    required String? projectId,
    required String? sessionTitle,
  }) async {
    final identity = _notificationIdentity(sessionId);

    final payload = jsonEncode(
      NotificationTapEvent(
        sessionId: sessionId,
        projectId: projectId,
        sessionTitle: sessionTitle,
      ).toJson(),
    );

    // A session notification reuses the same per-platform identity as the
    // background FCM notification, so showing the foreground one replaces any
    // existing notification for the session (and vice versa) on its own.
    await _plugin.show(
      id: identity.id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          category.id,
          category.displayName,
          tag: identity.androidTag,
          largeIcon: const DrawableResourceAndroidBitmap("@mipmap/ic_launcher"),
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> cancel({required int id, required String? tag}) async {
    await _plugin.cancel(id: id, tag: tag);
  }

  @override
  void cancelForSession({required String sessionId}) {
    final identity = _notificationIdentity(sessionId);
    unawaited(_safeCancel(id: identity.id, tag: identity.androidTag));
  }

  ({int id, String? androidTag}) _notificationIdentity(String? sessionId) {
    if (sessionId == null) {
      return (id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647), androidTag: null);
    }
    return notificationIdentityForSession(sessionId: sessionId, isAndroid: Platform.isAndroid);
  }

  /// The notification identity shared by [show] and [cancelForSession] so a
  /// foreground notification and the background notification the OS renders from
  /// FCM are the *same* notification (one per session).
  ///
  /// Android identifies notifications by the `(tag, id)` pair and FCM posts
  /// background notifications as `(tag, 0)`, so the local notification uses the
  /// same `(sessionKey, 0)`. iOS/macOS identify by the id alone, which equals
  /// the FCM `apns-collapse-id`, so they use `sessionKey` as the id.
  @visibleForTesting
  static ({int id, String? androidTag}) notificationIdentityForSession({
    required String sessionId,
    required bool isAndroid,
  }) {
    final sessionKey = sessionNotificationId(sessionId: sessionId);
    if (isAndroid) {
      return (id: 0, androidTag: sessionKey.toString());
    }
    return (id: sessionKey, androidTag: null);
  }

  Future<void> _safeCancel({required int id, required String? tag}) async {
    try {
      await cancel(id: id, tag: tag);
    } on Object catch (error, stackTrace) {
      logw("Failed to cancel notification for session", error, stackTrace);
    }
  }

  Future<void> dispose() => _notificationOpenedController.close();
}
