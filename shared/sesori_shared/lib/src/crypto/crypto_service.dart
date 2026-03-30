import "dart:convert";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";

import "session_encryptor.dart";

/// E2E encryption service for the relay protocol.
/// Uses X25519 for key exchange, HKDF-SHA256 for key derivation,
/// and XChaCha20-Poly1305 for symmetric encryption.
class RelayCryptoService {
  final _x25519 = X25519();
  final _cipher = Xchacha20.poly1305Aead();

  /// Generates an X25519 keypair for key exchange.
  Future<SimpleKeyPair> generateKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    return keyPair;
  }

  /// Derives a shared secret from own private key and peer's public key.
  /// Both sides derive the same shared secret via X25519 DH.
  Future<SecretKey> deriveSharedSecret(
    SimpleKeyPair ownKeyPair, {
    required SimplePublicKey peerPublicKey,
  }) async {
    return _x25519.sharedSecretKey(
      keyPair: ownKeyPair,
      remotePublicKey: peerPublicKey,
    );
  }

  /// Derives a 32-byte encryption key from the shared secret using HKDF-SHA256.
  /// NEVER use the raw DH output directly as a cipher key.
  Future<SecretKey> deriveEncryptionKey(SecretKey sharedSecret) async {
    final hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);
    final sharedSecretBytes = await sharedSecret.extractBytes();

    return hkdf.deriveKey(
      secretKey: SecretKey(sharedSecretBytes),
      info: utf8.encode("sesori-relay-v1"),
      nonce: Uint8List(
        32,
      ), // No salt — HKDF spec: use HashLen zeros (matches Go's hkdf.New with nil salt)
    );
  }

  /// Encrypts plaintext using XChaCha20-Poly1305.
  /// Returns: [24 bytes nonce][ciphertext + 16 byte auth tag]
  Future<List<int>> encrypt(List<int> plaintext, {required SecretKey key}) async {
    final secretBox = await _cipher.encrypt(plaintext, secretKey: key);

    // Layout: nonce (24 bytes) + ciphertext + mac (16 bytes)
    return [
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];
  }

  /// Decrypts ciphertext produced by [encrypt].
  /// Expects: [24 bytes nonce][ciphertext + 16 byte auth tag]
  /// Throws if authentication fails (tampered or wrong key).
  Future<List<int>> decrypt(List<int> data, {required SecretKey key}) async {
    if (data.length < 24 + 16) {
      throw ArgumentError(
        "Ciphertext too short: must be at least 40 bytes (24 nonce + 16 tag)",
      );
    }

    final nonce = data.sublist(0, 24);
    final ciphertextAndMac = data.sublist(24);
    final cipherText = ciphertextAndMac.sublist(
      0,
      ciphertextAndMac.length - 16,
    );
    final mac = Mac(ciphertextAndMac.sublist(ciphertextAndMac.length - 16));

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);

    return _cipher.decrypt(secretBox, secretKey: key);
  }

  /// Encodes a public key as base64url (no padding) for WebSocket transmission.
  Future<String> encodePublicKey(SimplePublicKey key) async {
    final bytes = key.bytes;
    return base64Url.encode(bytes).replaceAll("=", "");
  }

  /// Decodes a base64url-encoded public key.
  SimplePublicKey decodePublicKey(String encoded) {
    // Add padding back if needed
    final padded = encoded + "=" * ((4 - encoded.length % 4) % 4);
    final bytes = base64Url.decode(padded);
    return decodePublicKeyFromBytes(Uint8List.fromList(bytes));
  }

  /// Decodes a raw X25519 public key from bytes.
  SimplePublicKey decodePublicKeyFromBytes(Uint8List bytes) {
    if (bytes.length != 32) {
      throw FormatException(
        "Invalid X25519 public key: expected 32 bytes, got ${bytes.length}",
      );
    }
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  /// Creates a [SessionEncryptor] from a derived encryption key.
  /// Use this after key exchange is complete for all subsequent
  /// encrypt/decrypt operations.
  SessionEncryptor createSessionEncryptor(SecretKey encryptionKey) {
    return SessionEncryptor(cryptoService: this, encryptionKey: encryptionKey);
  }
}
