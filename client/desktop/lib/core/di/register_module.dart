import "package:device_info_plus/device_info_plus.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";

@module
abstract class RegisterModule {
  @lazySingleton
  http.Client get httpClient => http.Client();

  @lazySingleton
  DeviceInfoPlugin get deviceInfoPlugin => DeviceInfoPlugin();

  // Same "Sesori" keychain service label as the mobile app; the differing
  // bundle ids (com.sesori.desktop vs com.sesori.app) keep the two products'
  // keychain items isolated on macOS.
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage(
    mOptions: MacOsOptions(accountName: "Sesori"),
  );
}
