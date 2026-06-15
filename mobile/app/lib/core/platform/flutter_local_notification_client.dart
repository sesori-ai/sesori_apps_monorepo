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
    final id = sessionId == null
        ? DateTime.now().millisecondsSinceEpoch.remainder(2147483647)
        : sessionNotificationId(sessionId: sessionId);

    // A new notification for a session replaces any older one. On Android a
    // background notification rendered by the OS from an FCM message is posted
    // as (tag, 0); drop it before showing the foreground notification so only
    // the latest remains. iOS/macOS replace automatically because the local
    // notification reuses the same identifier as the FCM apns-collapse-id.
    if (sessionId != null) {
      await _cancelAndroidBackgroundNotification(id);
    }

    final payload = jsonEncode(
      NotificationTapEvent(
        sessionId: sessionId,
        projectId: projectId,
        sessionTitle: sessionTitle,
      ).toJson(),
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          category.id,
          category.displayName,
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
    unawaited(
      _cancelForSession(sessionNotificationId(sessionId: sessionId)).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        logw("Failed to cancel notifications for session", error, stackTrace);
      }),
    );
  }

  /// Dismisses every notification for a session, across the surfaces that may
  /// have rendered it:
  ///  - the local plugin (foreground) plus iOS/macOS delivered notifications,
  ///    keyed by the integer id: `cancel(id)`.
  ///  - the Android OS notification rendered from an FCM background message,
  ///    posted as `(tag, 0)`: `cancel(0, tag: id)`.
  Future<void> _cancelForSession(int id) async {
    await cancel(id: id, tag: null);
    await _cancelAndroidBackgroundNotification(id);
  }

  /// Android renders background FCM notifications via `notify(tag, 0)`, where the
  /// tag is the session-scoped id string the auth server sets. Removing
  /// `(tag, 0)` clears that notification. No-op elsewhere: on iOS/macOS the
  /// shared integer identifier already covers both foreground and background.
  Future<void> _cancelAndroidBackgroundNotification(int id) async {
    if (!Platform.isAndroid) {
      return;
    }
    await cancel(id: 0, tag: id.toString());
  }

  Future<void> dispose() => _notificationOpenedController.close();
}
