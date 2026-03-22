import "dart:io";

import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:injectable/injectable.dart";

enum SesoriNotificationChannel {
  aiInteraction(
    id: "ai_interaction",
    displayName: "AI Interactions",
    description: "Questions and permissions from AI",
    importance: Importance.high,
  ),
  sessionMessage(
    id: "session_message",
    displayName: "Session Messages",
    description: "New messages from AI sessions",
    importance: Importance.defaultImportance,
  ),
  connectionStatus(
    id: "connection_status",
    displayName: "Connection Status",
    description: "Bridge connection status changes",
    importance: Importance.high,
  ),
  systemUpdate(
    id: "system_update",
    displayName: "System Updates",
    description: "App and bridge updates",
    importance: Importance.low,
  )
  ;

  const SesoriNotificationChannel({
    required this.id,
    required this.displayName,
    required this.description,
    required this.importance,
  });

  final String id;
  final String displayName;
  final String description;
  final Importance importance;
}

@lazySingleton
class LocalNotificationManager {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      for (final channel in SesoriNotificationChannel.values) {
        await androidPlugin?.createNotificationChannel(
          AndroidNotificationChannel(
            channel.id,
            channel.displayName,
            description: channel.description,
            importance: channel.importance,
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
    required String channelId,
  }) async {
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(channelId, channelId),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
