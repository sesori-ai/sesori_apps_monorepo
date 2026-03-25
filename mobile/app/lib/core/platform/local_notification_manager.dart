import "dart:io";

import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "notification_id_utils.dart";

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

  LocalNotificationManager({required FlutterLocalNotificationsPlugin plugin}) : _plugin = plugin;

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
      ),
    );
  }

  Future<void> show({
    required String title,
    required String body,
    required NotificationCategory category,
    required String? sessionId,
  }) async {
    final channelId = category.id;

    final int id;
    if (sessionId != null && category == NotificationCategory.aiInteraction) {
      id = computeNotificationId(sessionId: sessionId, category: category);
    } else {
      id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }

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
      ),
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
