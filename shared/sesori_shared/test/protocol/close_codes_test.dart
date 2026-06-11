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
  });
}
