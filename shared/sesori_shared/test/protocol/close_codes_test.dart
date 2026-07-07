import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RelayCloseCodes", () {
    test("bridgeRevoked is 4006", () {
      expect(RelayCloseCodes.bridgeRevoked, equals(4006));
    });

    test("bridgeRevoked does not reconnect", () {
      expect(RelayCloseCodes.noReconnectCodes, contains(RelayCloseCodes.bridgeRevoked));
      expect(RelayCloseCodes.shouldReconnect(RelayCloseCodes.bridgeRevoked), isFalse);
    });

    test("normal and unknown codes reconnect", () {
      expect(RelayCloseCodes.shouldReconnect(null), isTrue);
      expect(RelayCloseCodes.shouldReconnect(1000), isTrue);
      expect(RelayCloseCodes.shouldReconnect(1006), isTrue);
    });

    test("bridgeReplaced is 4007 and still reconnects (long-backoff, not never)", () {
      expect(RelayCloseCodes.bridgeReplaced, equals(4007));
      expect(RelayCloseCodes.noReconnectCodes, isNot(contains(RelayCloseCodes.bridgeReplaced)));
      expect(RelayCloseCodes.shouldReconnect(RelayCloseCodes.bridgeReplaced), isTrue);
    });

    group("isBridgeReplaced", () {
      test("matches the dedicated 4007 code regardless of reason", () {
        expect(
          RelayCloseCodes.isBridgeReplaced(closeCode: 4007, closeReason: null),
          isTrue,
        );
        expect(
          RelayCloseCodes.isBridgeReplaced(closeCode: 4007, closeReason: "anything"),
          isTrue,
        );
      });

      test("matches the 1000/replaced rollout fallback", () {
        expect(
          RelayCloseCodes.isBridgeReplaced(closeCode: 1000, closeReason: "replaced"),
          isTrue,
        );
      });

      test("does not match a plain 1000 close or other codes", () {
        expect(RelayCloseCodes.isBridgeReplaced(closeCode: 1000, closeReason: null), isFalse);
        expect(RelayCloseCodes.isBridgeReplaced(closeCode: 1000, closeReason: "bye"), isFalse);
        expect(RelayCloseCodes.isBridgeReplaced(closeCode: 4006, closeReason: "replaced"), isFalse);
        expect(RelayCloseCodes.isBridgeReplaced(closeCode: null, closeReason: "replaced"), isFalse);
      });
    });
  });
}
