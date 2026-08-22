import "dart:convert";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:sesori_bridge/src/foundation/key_exchange.dart";
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

      final crypto = RelayCryptoService();
      final phoneKp = await crypto.generateKeyPair();
      final phonePub = await phoneKp.extractPublicKey();

      final kxMsg = RelayMessage.keyExchange(
        publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
      ) as RelayKeyExchange;

      final response = await manager.handleKeyExchange(message: kxMsg);
      final ready = await _decryptReady(response, phoneKp);
      final decodedRoomKey = base64Url.decode(
        base64Url.normalize(ready.roomKey),
      );

      expect(decodedRoomKey, equals(originalRoomKey));
    });

    test("handleKeyExchange round-trip returns prefixed framed data", () async {
      final manager = KeyExchangeManager(makeRoomKey());

      final crypto = RelayCryptoService();
      final phoneKp = await crypto.generateKeyPair();
      final phonePub = await phoneKp.extractPublicKey();
      final kxMsg = RelayMessage.keyExchange(
        publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
      ) as RelayKeyExchange;

      final encrypted = await manager.handleKeyExchange(message: kxMsg);

      expect(encrypted, isA<Uint8List>());
      const x25519PubKeyLen = 32;
      const protocolVersionLen = 1;
      const nonceLen = 24;
      const tagLen = 16;
      const minLen = x25519PubKeyLen + protocolVersionLen + nonceLen + tagLen;

      expect(encrypted.length, greaterThanOrEqualTo(minLen));
      expect(encrypted[x25519PubKeyLen], equals(protocolVersion));
    });

    test("key exchange starts without a preceding phone_connected event", () async {
      final manager = KeyExchangeManager(makeRoomKey());

      final crypto = RelayCryptoService();
      final phoneKp = await crypto.generateKeyPair();
      final phonePub = await phoneKp.extractPublicKey();
      final kxMsg = RelayMessage.keyExchange(
        publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
      ) as RelayKeyExchange;

      final response = await manager.handleKeyExchange(message: kxMsg);

      expect(response, isNotEmpty);
    });

    test("supports concurrent exchanges", () async {
      final manager = KeyExchangeManager(makeRoomKey());
      const connIDs = [1, 2, 3];

      final futures = connIDs.map((_) async {
        final crypto = RelayCryptoService();
        final phoneKp = await crypto.generateKeyPair();
        final phonePub = await phoneKp.extractPublicKey();
        final kxMsg = RelayMessage.keyExchange(
          publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
        ) as RelayKeyExchange;

        final result = await manager.handleKeyExchange(message: kxMsg);
        return result;
      });

      final results = await Future.wait(futures);
      for (final result in results) {
        expect(result, isNotEmpty);
      }
    });

    test("supports repeated exchanges", () async {
      final manager = KeyExchangeManager(makeRoomKey());

      Future<Uint8List> exchange() async {
        final crypto = RelayCryptoService();
        final phoneKp = await crypto.generateKeyPair();
        final phonePub = await phoneKp.extractPublicKey();
        final kxMsg = RelayMessage.keyExchange(
          publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
        ) as RelayKeyExchange;
        return await manager.handleKeyExchange(message: kxMsg);
      }

      expect(await exchange(), isNotEmpty);
      expect(await exchange(), isNotEmpty);
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
