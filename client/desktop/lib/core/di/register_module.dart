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

  // usesDataProtectionKeychain is OFF: the data-protection keychain requires a
  // provisioned keychain-access-group entitlement that this non-sandboxed
  // Developer-ID-style app (and every unsigned dev build) does not carry, so
  // every operation would fail with errSecMissingEntitlement (-34018). The
  // classic login keychain needs no entitlement. Classic mode is only usable
  // with flutter_secure_storage_darwin 0.4.2 or newer, which stops issuing
  // kSecAttrSynchronizable queries that also demand that entitlement
  // (juliansteenbakker/flutter_secure_storage#1104).
  //
  // accountName keeps the "com.sesori.desktop" keychain service so credentials
  // written by the retired native classic-Keychain client remain readable.
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage(
    mOptions: MacOsOptions(accountName: "com.sesori.desktop", usesDataProtectionKeychain: false),
  );
}
