import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";
import "package:record/record.dart";
import "package:sesori_shared/sesori_shared.dart";

@module
abstract class RegisterModule {
  @lazySingleton
  http.Client get httpClient => http.Client();

  @lazySingleton
  RelayCryptoService get relayCryptoService => RelayCryptoService();

  @lazySingleton
  AudioRecorder get audioRecorder => AudioRecorder();

  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage(
    mOptions: MacOsOptions(
      accountName: "Sesori",
      useDataProtectionKeyChain: false,
    ),
  );
}
