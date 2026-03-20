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

      final secret1 = await crypto.deriveSharedSecret(kp1, pub2);
      final secret2 = await crypto.deriveSharedSecret(kp2, pub1);

      final bytes1 = await secret1.extractBytes();
      final bytes2 = await secret2.extractBytes();
      expect(bytes1, equals(bytes2));
    });

    test("DH derived encryption key has 32-byte length", () async {
      final kp1 = await crypto.generateKeyPair();
      final kp2 = await crypto.generateKeyPair();
      final pub2 = await kp2.extractPublicKey();

      final secret = await crypto.deriveSharedSecret(kp1, pub2);
      final key = await crypto.deriveEncryptionKey(secret);

      expect((await key.extractBytes()).length, equals(32));
    });

    test("both sides derive identical encryption key", () async {
      final kp1 = await crypto.generateKeyPair();
      final kp2 = await crypto.generateKeyPair();
      final pub1 = await kp1.extractPublicKey();
      final pub2 = await kp2.extractPublicKey();

      final secret1 = await crypto.deriveSharedSecret(kp1, pub2);
      final secret2 = await crypto.deriveSharedSecret(kp2, pub1);

      final key1 = await crypto.deriveEncryptionKey(secret1);
      final key2 = await crypto.deriveEncryptionKey(secret2);

      expect(await key1.extractBytes(), equals(await key2.extractBytes()));
    });

    test("encrypt/decrypt round-trip returns original plaintext", () async {
      final key = SecretKey(List<int>.generate(32, (i) => i));
      final plaintext =
          "hello, world! this is a test message for XChaCha20-Poly1305"
              .codeUnits;

      final ciphertext = await crypto.encrypt(plaintext, key);
      expect(ciphertext, isNot(equals(plaintext)));

      final decrypted = await crypto.decrypt(ciphertext, key);
      expect(decrypted, equals(plaintext));
    });

    test("decrypt with wrong key fails", () async {
      final keyA = SecretKey(List<int>.generate(32, (i) => i));
      final keyB = SecretKey(List<int>.generate(32, (i) => i + 1));
      final plaintext = "secret message".codeUnits;

      final ciphertext = await crypto.encrypt(plaintext, keyA);

      expect(() => crypto.decrypt(ciphertext, keyB), throwsA(isA<Object>()));
    });

    test("SessionEncryptor round-trip", () async {
      final key = SecretKey(List<int>.generate(32, (i) => i * 3));
      final encryptor = crypto.createSessionEncryptor(key);
      final plaintext = "session encryptor round-trip test".codeUnits;

      final ciphertext = await encryptor.encrypt(plaintext);
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
