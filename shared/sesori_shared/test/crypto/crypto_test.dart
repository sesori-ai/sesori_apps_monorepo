import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("crypto", () {
    final crypto = RelayCryptoService();

    test("DH round-trip produces matching shared secrets", () async {
      final kp1 = await crypto.generateKeyPair();
      final kp2 = await crypto.generateKeyPair();
      final pub1 = await kp1.extractPublicKey();
      final pub2 = await kp2.extractPublicKey();

      final secret1 = await crypto.deriveSharedSecret(kp1, peerPublicKey: pub2);
      final secret2 = await crypto.deriveSharedSecret(kp2, peerPublicKey: pub1);

      final bytes1 = await secret1.extractBytes();
      final bytes2 = await secret2.extractBytes();
      expect(bytes1, equals(bytes2));
    });

    test("DH derived encryption key has 32-byte length", () async {
      final kp1 = await crypto.generateKeyPair();
      final kp2 = await crypto.generateKeyPair();
      final pub2 = await kp2.extractPublicKey();

      final secret = await crypto.deriveSharedSecret(kp1, peerPublicKey: pub2);
      final key = await crypto.deriveEncryptionKey(secret);

      expect((await key.extractBytes()).length, equals(32));
    });

    test("both sides derive identical encryption key", () async {
      final kp1 = await crypto.generateKeyPair();
      final kp2 = await crypto.generateKeyPair();
      final pub1 = await kp1.extractPublicKey();
      final pub2 = await kp2.extractPublicKey();

      final secret1 = await crypto.deriveSharedSecret(kp1, peerPublicKey: pub2);
      final secret2 = await crypto.deriveSharedSecret(kp2, peerPublicKey: pub1);

      final key1 = await crypto.deriveEncryptionKey(secret1);
      final key2 = await crypto.deriveEncryptionKey(secret2);

      expect(await key1.extractBytes(), equals(await key2.extractBytes()));
    });

    test("encrypt/decrypt round-trip returns original plaintext", () async {
      final key = SecretKey(List<int>.generate(32, (i) => i));
      final plaintext = "hello, world! this is a test message for XChaCha20-Poly1305".codeUnits;

      final ciphertext = await crypto.encrypt(plaintext, key: key);
      expect(ciphertext, isA<Uint8List>());
      expect(ciphertext, hasLength(24 + plaintext.length + 16));
      expect(ciphertext, isNot(equals(plaintext)));

      final secretBox = SecretBox(
        Uint8List.sublistView(ciphertext, 24, ciphertext.length - 16),
        nonce: Uint8List.sublistView(ciphertext, 0, 24),
        mac: Mac(Uint8List.sublistView(ciphertext, ciphertext.length - 16)),
      );
      expect(await Xchacha20.poly1305Aead().decrypt(secretBox, secretKey: key), equals(plaintext));

      final decrypted = await crypto.decrypt(ciphertext, key: key);
      expect(decrypted, equals(plaintext));
    });

    test("decrypt with wrong key fails", () async {
      final keyA = SecretKey(List<int>.generate(32, (i) => i));
      final keyB = SecretKey(List<int>.generate(32, (i) => i + 1));
      final plaintext = "secret message".codeUnits;

      final ciphertext = await crypto.encrypt(plaintext, key: keyA);

      expect(() => crypto.decrypt(ciphertext, key: keyB), throwsA(isA<Object>()));
    });

    test("SessionEncryptor round-trip", () async {
      final key = SecretKey(List<int>.generate(32, (i) => i * 3));
      final encryptor = crypto.createSessionEncryptor(key);
      final plaintext = "session encryptor round-trip test".codeUnits;

      final ciphertext = await encryptor.encrypt(plaintext);
      expect(ciphertext, isA<Uint8List>());
      final decrypted = await encryptor.decrypt(ciphertext);

      expect(decrypted, equals(plaintext));
    });

    test("SessionEncryptor with short key fails during encrypt", () async {
      final shortKey = SecretKey("too-short".codeUnits);
      final encryptor = crypto.createSessionEncryptor(shortKey);

      expect(
        () => encryptor.encrypt("hello".codeUnits),
        throwsA(isA<Object>()),
      );
    });

    test("encode/decode public key preserves bytes", () async {
      final kp = await crypto.generateKeyPair();
      final pub = await kp.extractPublicKey();

      final encoded = await crypto.encodePublicKey(pub);
      expect(encoded, isNotEmpty);

      final decoded = crypto.decodePublicKey(encoded);
      expect(decoded.bytes, equals(pub.bytes));
      expect(decoded.type, equals(KeyPairType.x25519));
    });
  });
}
