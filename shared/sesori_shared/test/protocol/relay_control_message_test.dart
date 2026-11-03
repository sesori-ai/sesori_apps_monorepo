import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RelayControlMessage", () {
    // Exactly what the relay's writeControl sends: {"type": ..., "connId": <uint16>}.
    test("decodes phone_connected", () {
      expect(
        RelayControlMessage.fromJson({"type": "phone_connected", "connId": 7}),
        const RelayControlMessage.phoneConnected(connId: 7),
      );
    });

    test("decodes phone_disconnected", () {
      expect(
        RelayControlMessage.fromJson({"type": "phone_disconnected", "connId": 65535}),
        const RelayControlMessage.phoneDisconnected(connId: 65535),
      );
    });

    test("decodes an unknown type to the fallback instead of throwing", () {
      expect(
        RelayControlMessage.fromJson({"type": "phone_renamed", "connId": 7}),
        isA<UnknownRelayControlMessage>(),
      );
    });

    test("rejects a known type without its connection id", () {
      expect(() => RelayControlMessage.fromJson({"type": "phone_connected"}), throwsA(isA<TypeError>()));
    });
  });
}
