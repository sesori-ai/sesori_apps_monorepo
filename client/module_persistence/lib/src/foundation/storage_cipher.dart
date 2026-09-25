import "dart:convert";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:injectable/injectable.dart";

import "persistence_scope.dart";
import "storage_exception.dart";

/// AES-256-GCM for individual rows, independent of relay encryption/framing.
@lazySingleton
class StorageCipher({required PersistenceScope scope}) {
  static const _version = 1;
  static const _keyLength = 32;
  static const _nonceLength = 12;
  static const _macLength = 16;

  final PersistenceScope _scope = scope;
  final AesGcm _algorithm = AesGcm.with256bits(nonceLength: _nonceLength);

  Future<SecretKey> generateMasterKey() => _algorithm.newSecretKey();

  Future<String> encodeMasterKey({required SecretKey masterKey}) async => base64Encode(await masterKey.extractBytes());

  SecretKey decodeMasterKey({required String encoded}) {
    try {
      final bytes = base64Decode(encoded);
      if (bytes.length != _keyLength) {
        throw const FormatException("The client master key must contain 32 bytes");
      }
      return SecretKeyData(bytes);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException(operation: StorageOperation.decodeMasterKey, innerError: error),
        stackTrace,
      );
    }
  }

  Future<Uint8List> encrypt({required String key, required String value, required SecretKey masterKey}) async {
    try {
      final box = await _algorithm.encrypt(
        utf8.encode(value),
        secretKey: masterKey,
        aad: _associatedData(key: key),
      );
      // The cipher generates a fresh 96-bit nonce for every encryption.
      return Uint8List.fromList([_version, ...box.concatenation()]);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException(operation: StorageOperation.encryptValue, innerError: error),
        stackTrace,
      );
    }
  }

  Future<String> decrypt({required String key, required Uint8List envelope, required SecretKey masterKey}) async {
    try {
      if (envelope.length < 1 + _nonceLength + _macLength) {
        throw const FormatException("Truncated client secret envelope");
      }
      if (envelope.first != _version) {
        throw FormatException("Unsupported client secret envelope version ${envelope.first}");
      }
      final box = SecretBox.fromConcatenation(
        envelope.sublist(1),
        nonceLength: _nonceLength,
        macLength: _macLength,
      );
      return utf8.decode(
        await _algorithm.decrypt(
          box,
          secretKey: masterKey,
          aad: _associatedData(key: key),
        ),
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException(operation: StorageOperation.decryptValue, innerError: error),
        stackTrace,
      );
    }
  }

  // Scope is a closed enum with explicit stable spellings. The final key is
  // opaque and may contain separators without changing the preceding fields.
  List<int> _associatedData({required String key}) =>
      utf8.encode("sesori-client-storage\u0000$_version\u0000${_scope.storageId}\u0000$key");
}
