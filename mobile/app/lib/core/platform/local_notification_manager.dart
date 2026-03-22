import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:injectable/injectable.dart";

@lazySingleton
class LocalNotificationManager {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const channels = [
      AndroidNotificationChannel(
        "ai_interaction",
        "AI Interactions",
        description: "Questions and permissions from AI",
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        "session_message",
        "Session Messages",
        description: "New messages from AI sessions",
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        "connection_status",
        "Connection Status",
        description: "Bridge connection status changes",
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        "system_update",
        "System Updates",
        description: "App and bridge updates",
        importance: Importance.low,
      ),
    ];

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in channels) {
      await androidImplementation?.createNotificationChannel(channel);
    }

    await _plugin.initialize(
      const InitializationSettings(
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
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(channelId, channelId),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
