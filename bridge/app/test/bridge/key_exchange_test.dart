import "dart:convert";

import "package:cryptography/cryptography.dart";
import "package:sesori_bridge/src/bridge/key_exchange.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  group("KeyExchangeManager", () {
    test("room key is copied and not affected by external mutation", () async {
      final roomKey = makeRoomKey();
      final originalRoomKey = List<int>.from(roomKey);
      final manager = KeyExchangeManager(roomKey);

      roomKey[0] ^= 0xFF;

      const connID = 1;
      manager.startExchange(connID);

      final crypto = RelayCryptoService();
      final phoneKp = await crypto.generateKeyPair();
      final phonePub = await phoneKp.extractPublicKey();

      final kxMsg =
          RelayMessage.keyExchange(
                publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
              )
              as RelayKeyExchange;

      final response = await manager.handleKeyExchange(connID, kxMsg);
      final ready = await _decryptReady(response, phoneKp);
      final decodedRoomKey = base64Url.decode(
        base64Url.normalize(ready.roomKey),
      );

      expect(decodedRoomKey, equals(originalRoomKey));
    });

    test("handleKeyExchange round-trip returns prefixed framed data", () async {
      final manager = KeyExchangeManager(makeRoomKey());
      const connID = 1;
      manager.startExchange(connID);

      final crypto = RelayCryptoService();
      final phoneKp = await crypto.generateKeyPair();
      final phonePub = await phoneKp.extractPublicKey();
      final kxMsg =
          RelayMessage.keyExchange(
                publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
              )
              as RelayKeyExchange;

      final encrypted = await manager.handleKeyExchange(connID, kxMsg);

      const x25519PubKeyLen = 32;
      const protocolVersionLen = 1;
      const nonceLen = 24;
      const tagLen = 16;
      const minLen = x25519PubKeyLen + protocolVersionLen + nonceLen + tagLen;

      expect(encrypted.length, greaterThanOrEqualTo(minLen));
      expect(encrypted[x25519PubKeyLen], equals(protocolVersion));
    });

    test("handleKeyExchange throws when no exchange is pending", () async {
      final manager = KeyExchangeManager(makeRoomKey());

      final crypto = RelayCryptoService();
      final phoneKp = await crypto.generateKeyPair();
      final phonePub = await phoneKp.extractPublicKey();
      final kxMsg =
          RelayMessage.keyExchange(
                publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
              )
              as RelayKeyExchange;

      expect(
        () => manager.handleKeyExchange(1, kxMsg),
        throwsA(isA<StateError>()),
      );
    });

    test("supports concurrent exchanges", () async {
      final manager = KeyExchangeManager(makeRoomKey());
      const connIDs = [1, 2, 3];

      connIDs.forEach(manager.startExchange);

      final futures = connIDs.map((connID) async {
        final crypto = RelayCryptoService();
        final phoneKp = await crypto.generateKeyPair();
        final phonePub = await phoneKp.extractPublicKey();
        final kxMsg =
            RelayMessage.keyExchange(
                  publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
                )
                as RelayKeyExchange;

        final result = await manager.handleKeyExchange(connID, kxMsg);
        return result;
      });

      final results = await Future.wait(futures);
      for (final result in results) {
        expect(result, isNotEmpty);
      }
    });

    test(
      "startExchange twice for same connID replaces stale pending exchange",
      () async {
        final manager = KeyExchangeManager(makeRoomKey());
        const connID = 42;

        manager.startExchange(connID);
        manager.startExchange(connID);

        final crypto = RelayCryptoService();
        final phoneKp = await crypto.generateKeyPair();
        final phonePub = await phoneKp.extractPublicKey();
        final kxMsg =
            RelayMessage.keyExchange(
                  publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
                )
                as RelayKeyExchange;

        final result = await manager.handleKeyExchange(connID, kxMsg);
        expect(result, isNotEmpty);
      },
    );

    test("removeExchange clears pending exchange", () async {
      final manager = KeyExchangeManager(makeRoomKey());
      const connID = 10;

      manager.startExchange(connID);
      manager.removeExchange(connID);

      final crypto = RelayCryptoService();
      final phoneKp = await crypto.generateKeyPair();
      final phonePub = await phoneKp.extractPublicKey();
      final kxMsg =
          RelayMessage.keyExchange(
                publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
              )
              as RelayKeyExchange;

      expect(
        () => manager.handleKeyExchange(connID, kxMsg),
        throwsA(isA<StateError>()),
      );
    });
  });
}

Future<RelayReady> _decryptReady(
  List<int> response,
  SimpleKeyPair phoneKp,
) async {
  final bridgePublicKeyBytes = response.sublist(0, 32);
  final encryptedFrame = response.sublist(32);

  final crypto = RelayCryptoService();
  final bridgePublicKey = SimplePublicKey(
    bridgePublicKeyBytes,
    type: KeyPairType.x25519,
  );
  final secret = await crypto.deriveSharedSecret(phoneKp, peerPublicKey: bridgePublicKey);
  final key = await crypto.deriveEncryptionKey(secret);
  final encryptor = crypto.createSessionEncryptor(key);

  final decrypted = await unframe(encryptedFrame, encryptor: encryptor);
  final message = RelayMessage.fromJson(
    jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>,
  );

  expect(message, isA<RelayReady>());
  return message as RelayReady;
}
