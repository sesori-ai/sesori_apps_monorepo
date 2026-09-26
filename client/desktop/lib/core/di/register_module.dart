import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart" show kReleaseMode;
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../platform/desktop_master_key_store.dart";

// Injectable module providers require a class; bootstrap registers this enum value explicitly.
const clientPersistenceScope = kReleaseMode ? PersistenceScope.production : PersistenceScope.development;

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

  @lazySingleton
  MasterKeyStore masterKeyStore({required PersistenceScope scope}) => DesktopMasterKeyStore(
    scope: scope,
    storage: const FlutterSecureStorage(
      // Classic Keychain requires no new access-group entitlement or ACL change.
      mOptions: MacOsOptions(accountName: PersistenceScope.masterKeyNamespace, usesDataProtectionKeychain: false),
    ),
  );
}
