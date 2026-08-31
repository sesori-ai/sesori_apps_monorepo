import "package:device_info_plus/device_info_plus.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:http/http.dart" as http;
import "package:image_picker/image_picker.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:universal_platform/universal_platform.dart";

import "../platform/desktop_file_image_saver.dart";
import "../platform/file_save_client.dart";
import "../platform/gal_client.dart";
import "../platform/mobile_photo_image_saver.dart";

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
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage(
    mOptions: MacOsOptions(
      accountName: "Sesori",
    ),
  );
}
