import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart" show kReleaseMode;
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:http/http.dart" as http;
import "package:image_picker/image_picker.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:universal_platform/universal_platform.dart";

import "../platform/deprecated_native_storage_v1/flutter_legacy_native_storage_adapter.dart";
import "../platform/desktop_file_image_saver.dart";
import "../platform/file_save_client.dart";
import "../platform/flutter_master_key_store.dart";
import "../platform/gal_client.dart";
import "../platform/mobile_photo_image_saver.dart";

// Injectable module providers require a class; bootstrap registers this enum value explicitly.
const clientPersistenceScope = kReleaseMode ? PersistenceScope.production : PersistenceScope.development;

@module
abstract class RegisterModule() {
  @lazySingleton
  http.Client get httpClient => http.Client();

  @lazySingleton
  RelayCryptoService get relayCryptoService => RelayCryptoService();

  @lazySingleton
  ImagePicker get imagePicker => ImagePicker();

  @lazySingleton
  FlutterLocalNotificationsPlugin get flutterLocalNotificationsPlugin => FlutterLocalNotificationsPlugin();

  @lazySingleton
  DeviceInfoPlugin get deviceInfoPlugin => DeviceInfoPlugin();

  @lazySingleton
  NotificationCanceller notificationCanceller(LocalNotificationClient client) => client;

  @lazySingleton
  ImageSaver imageSaver({required GalClient galClient, required FileSaveClient fileSaveClient}) =>
      UniversalPlatform.isWeb || UniversalPlatform.isMacOS || UniversalPlatform.isLinux || UniversalPlatform.isWindows
      ? DesktopFileImageSaver(fileSaveClient: fileSaveClient)
      : MobilePhotoImageSaver(galClient: galClient);

  @lazySingleton
  MasterKeyStore masterKeyStore({required PersistenceScope scope}) => FlutterMasterKeyStore(
    scope: scope,
    storage: const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false, storageNamespace: PersistenceScope.masterKeyNamespace),
      iOptions: IOSOptions(accountName: PersistenceScope.masterKeyNamespace),
    ),
  );

  // Temporary old-keyspace capability; neither creating the adapter nor lazy
  // registration performs native I/O. Only production startup resolves it.
  @lazySingleton
  LegacyNativeStorage legacyNativeStorage() => FlutterLegacyNativeStorageAdapter(
    storage: const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
      // Query all old accessibility classes without mutating their protection.
      iOptions: IOSOptions(accessibility: null),
      mOptions: MacOsOptions(accountName: "Sesori"),
    ),
  );
}
