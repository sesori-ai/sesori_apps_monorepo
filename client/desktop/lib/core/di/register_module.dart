import "package:device_info_plus/device_info_plus.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

@module
abstract class RegisterModule() {
  @lazySingleton
  http.Client get httpClient => http.Client();

  @lazySingleton
  DeviceInfoPlugin get deviceInfoPlugin => DeviceInfoPlugin();

  @lazySingleton
  FlutterLocalNotificationsPlugin get flutterLocalNotificationsPlugin => FlutterLocalNotificationsPlugin();

  @lazySingleton
  NotificationCanceller notificationCanceller({required LocalNotificationClient client}) => client;

  @lazySingleton
  RelayCryptoService get relayCryptoService => RelayCryptoService();

  // Used by Windows and Linux. The desktop storage adapter routes macOS to the
  // dedicated classic-Keychain channel required by non-provisioned builds.
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();
}
