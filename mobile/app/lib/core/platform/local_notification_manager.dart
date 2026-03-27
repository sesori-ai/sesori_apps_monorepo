import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "notification_id_utils.dart";
import "notification_tap_event.dart";
export "notification_tap_event.dart";

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

@lazySingleton
class LocalNotificationManager implements NotificationCanceller {
  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<NotificationTapEvent> _tapController = StreamController.broadcast();

  LocalNotificationManager({required FlutterLocalNotificationsPlugin plugin}) : _plugin = plugin;

  Stream<NotificationTapEvent> get onNotificationTapped => _tapController.stream;

  Future<void> initialize() async {
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
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  @visibleForTesting
  void handleNotificationResponseForTesting(NotificationResponse response) => _onNotificationTapped(response);

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      _tapController.add(const NotificationTapEvent(sessionId: null, projectId: null));
      return;
    }

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _tapController.add(NotificationTapEvent.fromJson(data));
    } catch (_) {
      _tapController.add(const NotificationTapEvent(sessionId: null, projectId: null));
    }
  }

  Future<void> show({
    required String title,
    required String body,
    required NotificationCategory category,
    required String? sessionId,
    required String? projectId,
  }) async {
    final channelId = category.id;

    final int id;
    if (sessionId != null && category == NotificationCategory.aiInteraction) {
      id = computeNotificationId(sessionId: sessionId, category: category);
    } else {
      id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }

    final payload = jsonEncode(
      NotificationTapEvent(sessionId: sessionId, projectId: projectId).toJson(),
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          category.displayName,
          largeIcon: const DrawableResourceAndroidBitmap("@mipmap/ic_launcher"),
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> cancel(int notificationId) async {
    await _plugin.cancel(id: notificationId);
  }

  @override
  void cancelForSession({required String sessionId, required NotificationCategory category}) {
    cancel(computeNotificationId(sessionId: sessionId, category: category));
  }
}
