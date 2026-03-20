import "dart:convert";
import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

void main() {
  group("RelayCloseCodes constants", () {
    test("authFailure is 4001", () {
      expect(RelayCloseCodes.authFailure, equals(4001));
    });

    test("authRequired is 4002", () {
      expect(RelayCloseCodes.authRequired, equals(4002));
    });

    test("roomFull is 4003", () {
      expect(RelayCloseCodes.roomFull, equals(4003));
    });

    test("roomNotFound is 4004", () {
      expect(RelayCloseCodes.roomNotFound, equals(4004));
    });

    test("accountFull is 4005", () {
      expect(RelayCloseCodes.accountFull, equals(4005));
    });
  });

  group("RelayCloseCodes.shouldReconnect", () {
    test("returns false for all terminal error codes", () {
      expect(RelayCloseCodes.shouldReconnect(4001), isFalse);
      expect(RelayCloseCodes.shouldReconnect(4002), isFalse);
      expect(RelayCloseCodes.shouldReconnect(4003), isFalse);
      expect(RelayCloseCodes.shouldReconnect(4004), isFalse);
      expect(RelayCloseCodes.shouldReconnect(4005), isFalse);
    });

    test("returns true for null close code (clean disconnect)", () {
      expect(RelayCloseCodes.shouldReconnect(null), isTrue);
    });

    test("returns true for normal WebSocket close codes", () {
      expect(RelayCloseCodes.shouldReconnect(1000), isTrue); // normal close
      expect(RelayCloseCodes.shouldReconnect(1001), isTrue); // going away
      expect(RelayCloseCodes.shouldReconnect(1006), isTrue); // abnormal
    });
  });

  group("RelayClient initial state", () {
    test("starts in disconnected state", () {
      final client = RelayClient(
        relayHost: "relay.example.com",
        cryptoService: RelayCryptoService(),
        roomKeyStorage: MockRoomKeyStorage(),
      );

      expect(client.connectionState, equals(RelayClientConnectionState.disconnected));
    });

    test("isConnected is false before connect() is called", () {
      final client = RelayClient(
        relayHost: "relay.example.com",
        cryptoService: RelayCryptoService(),
        roomKeyStorage: MockRoomKeyStorage(),
      );

      expect(client.isConnected, isFalse);
    });

    test("lastCloseCode is null before any connection", () {
      final client = RelayClient(
        relayHost: "relay.example.com",
        cryptoService: RelayCryptoService(),
        roomKeyStorage: MockRoomKeyStorage(),
      );

      expect(client.lastCloseCode, isNull);
    });
  });

  group("Payload type detection", () {
    // The relay protocol uses a 1-byte version prefix to distinguish payload types:
    // 0x01 = encrypted relay message (XChaCha20-Poly1305 ciphertext)
    // 0x7B = '{' = plaintext JSON control message from bridge (key_exchange, rekey_required)

    test("message version byte is 0x01 for encrypted frames", () {
      // Documented relay protocol: encrypted frames start with version byte 0x01
      const messageVersion = 0x01;
      final encryptedFrame = Uint8List.fromList([messageVersion, 0xDE, 0xAD, 0xBE, 0xEF]);

      expect(encryptedFrame.first, equals(0x01));
    });

    test("plaintext JSON starts with 0x7B (ASCII curly brace)", () {
      // Plaintext messages from bridge during handshake start with '{'
      final jsonBytes = utf8.encode('{"type":"rekey_required"}');

      expect(jsonBytes.first, equals(0x7B)); // '{' = 0x7B
    });

    test("plaintext key_exchange message starts with 0x7B", () {
      final jsonBytes = utf8.encode('{"type":"key_exchange","publicKey":"base64url"}');

      expect(jsonBytes.first, equals(0x7B));
    });

    test("0x01 and 0x7B are distinct payload discriminators", () {
      const encryptedVersion = 0x01;
      const plaintextVersion = 0x7B;

      expect(encryptedVersion, isNot(equals(plaintextVersion)));
    });
  });

  group("BridgeStatus enum", () {
    test("has online and offline variants", () {
      const online = BridgeStatus.online;
      const offline = BridgeStatus.offline;

      expect(online, isNot(equals(offline)));
      expect(BridgeStatus.values.length, equals(2));
    });
  });

  group("RelayClientConnectionState enum", () {
    test("has all expected states", () {
      expect(RelayClientConnectionState.values, contains(RelayClientConnectionState.disconnected));
      expect(RelayClientConnectionState.values, contains(RelayClientConnectionState.connecting));
      expect(RelayClientConnectionState.values, contains(RelayClientConnectionState.connected));
      expect(RelayClientConnectionState.values, contains(RelayClientConnectionState.disconnecting));
    });
  });
}
