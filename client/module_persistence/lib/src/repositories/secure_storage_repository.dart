import "dart:async";

import "package:cryptography/cryptography.dart";
import "package:injectable/injectable.dart";

import "../api/secure_storage_api.dart";
import "../foundation/keys/secret_storage_key.dart";
import "../foundation/storage_cipher.dart";
import "../foundation/storage_exception.dart";

/// One cached initialization future per process-owned repository. A denied or
/// invalid key stays failed for this instance, so callers cannot fan out more
/// native authorization requests. Explicit startup reset is the only replacement
/// boundary. No value cache or custom write queue exists.
@lazySingleton
class SecureStorageRepository({required SecureStorageApi storageApi, required StorageCipher cipher}) {
  final SecureStorageApi _api = storageApi;
  final StorageCipher _cipher = cipher;
  Future<SecretKey>? _masterKey;

  Future<String?> read({required SecretStorageKey key}) async {
    final ciphertext = await _api.readCiphertext(key: key.storageKey);
    if (ciphertext == null) return null;
    return await _cipher.decrypt(key: key.storageKey, envelope: ciphertext, masterKey: await _getMasterKey());
  }

  Future<void> write({required SecretStorageKey key, required String value}) async {
    final masterKey = await _getMasterKey();
    final ciphertext = await _cipher.encrypt(key: key.storageKey, value: value, masterKey: masterKey);
    await _api.writeCiphertext(key: key.storageKey, ciphertext: ciphertext);
  }

  Future<void> delete({required SecretStorageKey key}) => _api.deleteCiphertext(key: key.storageKey);

  /// Destructive startup recovery, before consumers or concurrent secret work.
  /// Clear this scope's ciphertext and replace its native master. A failed reset
  /// stays cached too: remaining partial rows must not restore an old session.
  Future<void> reset() async {
    final resetting = _resetMasterKey();
    _masterKey = resetting;
    await resetting;
  }

  Future<SecretKey> _resetMasterKey() async {
    // Attempt both even if one fails. Rotating the master also invalidates old
    // ciphertext on relaunch when SQL cleanup failed but native access worked.
    // Record.wait retains both errors; publish the key only after both succeed.
    final (_, masterKey) = await (_api.clearCiphertexts(), _createMasterKey()).wait;
    return masterKey;
  }

  Future<SecretKey> _getMasterKey() => _masterKey ??= _initializeMasterKey();

  Future<SecretKey> _initializeMasterKey() async {
    final encoded = await _api.readMasterKey();
    if (encoded != null) return _cipher.decodeMasterKey(encoded: encoded);
    if (await _api.hasEncryptedValues()) throw const MasterKeyMissingException();
    return await _createMasterKey();
  }

  Future<SecretKey> _createMasterKey() async {
    final masterKey = await _cipher.generateMasterKey();
    // Persist the only recovery key before any encrypted row can be committed.
    await _api.writeMasterKey(value: await _cipher.encodeMasterKey(masterKey: masterKey));
    return masterKey;
  }
}
