import "package:device_info_plus/device_info_plus.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";

@module
abstract class RegisterModule() {
  @lazySingleton
  http.Client get httpClient => http.Client();

  @lazySingleton
  DeviceInfoPlugin get deviceInfoPlugin => DeviceInfoPlugin();

  // Used by Windows and Linux. The desktop storage adapter routes macOS to the
  // dedicated classic-Keychain channel required by non-provisioned builds.
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();
}
