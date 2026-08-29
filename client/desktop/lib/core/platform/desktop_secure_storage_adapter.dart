import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "macos_legacy_keychain_client.dart";

/// Desktop [SecureStorage] backed by the OS credential store
/// (macOS Keychain, Windows Credential Manager/DPAPI, Linux libsecret).
@LazySingleton(as: SecureStorage)
class DesktopSecureStorageAdapter.forTesting({
  required final FlutterSecureStorage _storage,
  required final MacOsLegacyKeychainClient _macOsKeychainClient,
  required final bool _isMacOS,
}) implements SecureStorage {
  new({
    required FlutterSecureStorage storage,
    required MacOsLegacyKeychainClient macOsKeychainClient,
  }) : this.forTesting(
         storage: storage,
         macOsKeychainClient: macOsKeychainClient,
         isMacOS: Platform.isMacOS,
       );

  @visibleForTesting
  this;

  @override
  Future<String?> read({required String key}) =>
      _isMacOS ? _macOsKeychainClient.read(key: key) : _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _isMacOS ? _macOsKeychainClient.write(key: key, value: value) : _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) =>
      _isMacOS ? _macOsKeychainClient.delete(key: key) : _storage.delete(key: key);
}
