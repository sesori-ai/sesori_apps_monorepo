import "package:test/test.dart";
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
        authToken: null,
      );

      expect(client.connectionState, equals(RelayClientConnectionState.disconnected));
    });

    test("isConnected is false before connect() is called", () {
      final client = RelayClient(
        relayHost: "relay.example.com",
        cryptoService: RelayCryptoService(),
        roomKeyStorage: MockRoomKeyStorage(),
        authToken: null,
      );

      expect(client.isConnected, isFalse);
    });

    test("lastCloseCode is null before any connection", () {
      final client = RelayClient(
        relayHost: "relay.example.com",
        cryptoService: RelayCryptoService(),
        roomKeyStorage: MockRoomKeyStorage(),
        authToken: null,
      );

      expect(client.lastCloseCode, isNull);
    });
  });
}
