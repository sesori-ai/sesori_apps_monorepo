import "dart:convert";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_shared/sesori_shared.dart";

void main() {
  late RelayCryptoService service;

  setUp(() {
    service = RelayCryptoService();
  });

  group("RelayCryptoService", () {
    test("X25519 key generation produces a valid keypair", () async {
      final keyPair = await service.generateKeyPair();
      final publicKey = await keyPair.extractPublicKey();

      // X25519 public keys are always 32 bytes
      expect(publicKey.bytes.length, equals(32));
      expect(publicKey.type, equals(KeyPairType.x25519));
    });

    test("DH key exchange round-trip: both sides derive the same shared secret", () async {
      final aliceKeyPair = await service.generateKeyPair();
      final bobKeyPair = await service.generateKeyPair();

      final alicePublic = await aliceKeyPair.extractPublicKey();
      final bobPublic = await bobKeyPair.extractPublicKey();

      final aliceShared = await service.deriveSharedSecret(aliceKeyPair, peerPublicKey: bobPublic);
      final bobShared = await service.deriveSharedSecret(bobKeyPair, peerPublicKey: alicePublic);

      final aliceBytes = await aliceShared.extractBytes();
      final bobBytes = await bobShared.extractBytes();

      expect(aliceBytes, equals(bobBytes));
    });

    test("HKDF derivation produces a 32-byte key", () async {
      final keyPair = await service.generateKeyPair();
      final peerKeyPair = await service.generateKeyPair();
      final peerPublic = await peerKeyPair.extractPublicKey();

      final sharedSecret = await service.deriveSharedSecret(keyPair, peerPublicKey: peerPublic);
      final encryptionKey = await service.deriveEncryptionKey(sharedSecret);
      final keyBytes = await encryptionKey.extractBytes();

      expect(keyBytes.length, equals(32));
    });

    test("HKDF is deterministic: same shared secret produces same encryption key", () async {
      final rawBytes = Uint8List.fromList(List.generate(32, (i) => i));
      final sharedSecret1 = SecretKey(rawBytes.toList());
      final sharedSecret2 = SecretKey(rawBytes.toList());

      final key1 = await service.deriveEncryptionKey(sharedSecret1);
      final key2 = await service.deriveEncryptionKey(sharedSecret2);

      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();

      expect(bytes1, equals(bytes2));
    });

    test("XChaCha20-Poly1305 encrypt/decrypt round-trip preserves plaintext", () async {
      final keyPair = await service.generateKeyPair();
      final peerKeyPair = await service.generateKeyPair();
      final peerPublic = await peerKeyPair.extractPublicKey();
      final sharedSecret = await service.deriveSharedSecret(keyPair, peerPublicKey: peerPublic);
      final encryptionKey = await service.deriveEncryptionKey(sharedSecret);

      final plaintext = utf8.encode('{"type":"request","id":"1","method":"GET","path":"/health","headers":{}}');
      final ciphertext = await service.encrypt(plaintext, key: encryptionKey);
      final decrypted = await service.decrypt(ciphertext, key: encryptionKey);

      expect(decrypted, equals(plaintext));
    });

    test("encrypted output has nonce (24 bytes) + ciphertext + mac (16 bytes)", () async {
      final rawKey = Uint8List.fromList(List.generate(32, (i) => i));
      final key = SecretKey(rawKey.toList());

      final plaintext = utf8.encode("hello relay");
      final ciphertext = await service.encrypt(plaintext, key: key);

      // nonce(24) + ciphertext(plaintext.length) + mac(16)
      expect(ciphertext.length, equals(24 + plaintext.length + 16));
    });

    test("decrypt with wrong key throws (authentication failure)", () async {
      final rightKey = SecretKey(List.generate(32, (i) => i));
      final wrongKey = SecretKey(List.generate(32, (i) => 255 - i));

      final plaintext = utf8.encode("secret message");
      final ciphertext = await service.encrypt(plaintext, key: rightKey);

      expect(
        () => service.decrypt(ciphertext, key: wrongKey),
        throwsA(anything),
      );
    });

    test("decrypt of ciphertext shorter than 40 bytes throws ArgumentError", () async {
      final key = SecretKey(List.generate(32, (i) => i));
      final tooShort = List<int>.filled(39, 0);

      expect(
        () => service.decrypt(tooShort, key: key),
        throwsA(isA<ArgumentError>()),
      );
    });

    test("encodePublicKey produces unpadded base64url string", () async {
      final keyPair = await service.generateKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final encoded = await service.encodePublicKey(publicKey);

      // Should be base64url without padding '='
      expect(encoded.contains("="), isFalse);
      // X25519 32-byte key → 43 base64url chars (ceil(32*4/3) = 43, no padding needed exactly)
      expect(encoded.length, greaterThan(0));
    });

    test("decodePublicKey round-trip returns same bytes", () async {
      final keyPair = await service.generateKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final encoded = await service.encodePublicKey(publicKey);
      final decoded = service.decodePublicKey(encoded);

      expect(decoded.bytes, equals(publicKey.bytes));
      expect(decoded.type, equals(KeyPairType.x25519));
    });

    test("decodePublicKey rejects keys that are not 32 bytes", () async {
      // Encode fewer than 32 bytes — not a valid X25519 key
      final shortBytes = Uint8List.fromList(List.generate(16, (i) => i));
      final encoded = base64Url.encode(shortBytes).replaceAll("=", "");

      expect(
        () => service.decodePublicKey(encoded),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group("SessionEncryptor", () {
    test("encrypt/decrypt via SessionEncryptor preserves plaintext", () async {
      final keyPair = await service.generateKeyPair();
      final peerKeyPair = await service.generateKeyPair();
      final peerPublic = await peerKeyPair.extractPublicKey();
      final sharedSecret = await service.deriveSharedSecret(keyPair, peerPublicKey: peerPublic);
      final encryptionKey = await service.deriveEncryptionKey(sharedSecret);

      final encryptor = service.createSessionEncryptor(encryptionKey);

      final plaintext = utf8.encode('{"type":"sse_subscribe","path":"/global/event"}');
      final ciphertext = await encryptor.encrypt(plaintext);
      final decrypted = await encryptor.decrypt(ciphertext);

      expect(decrypted, equals(plaintext));
    });

    test("two independent SessionEncryptors with same key produce interoperable output", () async {
      final rawKey = List.generate(32, (i) => i);
      final key1 = SecretKey(List.from(rawKey));
      final key2 = SecretKey(List.from(rawKey));

      final encryptorA = service.createSessionEncryptor(key1);
      final encryptorB = service.createSessionEncryptor(key2);

      final plaintext = utf8.encode("interop test");
      final ciphertext = await encryptorA.encrypt(plaintext);
      final decrypted = await encryptorB.decrypt(ciphertext);

      expect(decrypted, equals(plaintext));
    });
  });
}
