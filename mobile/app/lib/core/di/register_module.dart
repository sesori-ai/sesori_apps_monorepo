import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";
import "package:record/record.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../platform/local_notification_manager.dart";

@module
abstract class RegisterModule {
  @lazySingleton
  http.Client get httpClient => http.Client();

  @lazySingleton
  RelayCryptoService get relayCryptoService => RelayCryptoService();

  @lazySingleton
  AudioRecorder get audioRecorder => AudioRecorder();

  @lazySingleton
  FlutterLocalNotificationsPlugin get flutterLocalNotificationsPlugin => FlutterLocalNotificationsPlugin();

  @lazySingleton
  NotificationCanceller notificationCanceller(LocalNotificationManager manager) => manager;

  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage(
    mOptions: MacOsOptions(
      accountName: "Sesori",
    ),
  );
}
