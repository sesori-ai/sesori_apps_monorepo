import "package:cryptography/cryptography.dart";

import "crypto_service.dart";

/// Stateful wrapper holding the derived encryption key for a relay session.
/// Created after key exchange completes. Used for all encrypt/decrypt operations.
class SessionEncryptor {
  final RelayCryptoService _cryptoService;
  final SecretKey _encryptionKey;

  SessionEncryptor({
    required RelayCryptoService cryptoService,
    required SecretKey encryptionKey,
  }) : _cryptoService = cryptoService,
       _encryptionKey = encryptionKey;

  /// Encrypts plaintext bytes using the session encryption key.
  /// Returns: [24 bytes nonce][ciphertext + 16 byte auth tag]
  Future<List<int>> encrypt(List<int> plaintext) {
    return _cryptoService.encrypt(plaintext, _encryptionKey);
  }

  /// Decrypts ciphertext using the session encryption key.
  /// Throws if authentication fails.
  Future<List<int>> decrypt(List<int> ciphertext) {
    return _cryptoService.decrypt(ciphertext, _encryptionKey);
  }
}
