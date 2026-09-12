import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Desktop [SecureStorage] backed by the OS credential store
/// (macOS Keychain, Windows Credential Manager/DPAPI, Linux libsecret).
@LazySingleton(as: SecureStorage)
class DesktopSecureStorageAdapter(final FlutterSecureStorage _storage) implements SecureStorage {
  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) => _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}
