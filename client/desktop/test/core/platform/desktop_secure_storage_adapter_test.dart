import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/desktop_secure_storage_adapter.dart";
import "package:sesori_desktop/core/platform/macos_legacy_keychain_client.dart";

void main() {
  late _MockFlutterSecureStorage storage;
  late _MockMacOsLegacyKeychainClient macOsKeychainClient;

  setUp(() {
    storage = _MockFlutterSecureStorage();
    macOsKeychainClient = _MockMacOsLegacyKeychainClient();
  });

  test("routes macOS operations through the classic login-Keychain client", () async {
    when(() => macOsKeychainClient.read(key: "token")).thenAnswer((_) async => "stored");
    when(() => macOsKeychainClient.write(key: "token", value: "fresh")).thenAnswer((_) async {});
    when(() => macOsKeychainClient.delete(key: "token")).thenAnswer((_) async {});
    final SecureStorage adapter = DesktopSecureStorageAdapter.forTesting(
      storage: storage,
      macOsKeychainClient: macOsKeychainClient,
      isMacOS: true,
    );

    expect(await adapter.read(key: "token"), "stored");
    await adapter.write(key: "token", value: "fresh");
    await adapter.delete(key: "token");

    verifyNever(() => storage.read(key: any(named: "key")));
    verifyNever(
      () => storage.write(
        key: any(named: "key"),
        value: any(named: "value"),
      ),
    );
    verifyNever(() => storage.delete(key: any(named: "key")));
  });

  test("keeps flutter_secure_storage for Windows and Linux", () async {
    when(() => storage.read(key: "token")).thenAnswer((_) async => "stored");
    when(() => storage.write(key: "token", value: "fresh")).thenAnswer((_) async {});
    when(() => storage.delete(key: "token")).thenAnswer((_) async {});
    final SecureStorage adapter = DesktopSecureStorageAdapter.forTesting(
      storage: storage,
      macOsKeychainClient: macOsKeychainClient,
      isMacOS: false,
    );

    expect(await adapter.read(key: "token"), "stored");
    await adapter.write(key: "token", value: "fresh");
    await adapter.delete(key: "token");

    verifyNever(() => macOsKeychainClient.read(key: any(named: "key")));
    verifyNever(
      () => macOsKeychainClient.write(
        key: any(named: "key"),
        value: any(named: "value"),
      ),
    );
    verifyNever(() => macOsKeychainClient.delete(key: any(named: "key")));
  });
}

class _MockFlutterSecureStorage() extends Mock implements FlutterSecureStorage;

class _MockMacOsLegacyKeychainClient() extends Mock implements MacOsLegacyKeychainClient;
