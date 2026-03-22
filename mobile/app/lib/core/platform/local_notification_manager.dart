import "dart:io";

import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

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
class LocalNotificationManager {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

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
        android: AndroidInitializationSettings("@mipmap/ic_launcher"),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  Future<void> show({
    required String title,
    required String body,
    required NotificationCategory category,
  }) async {
    final channelId = category.id;

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(channelId, category.displayName),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
