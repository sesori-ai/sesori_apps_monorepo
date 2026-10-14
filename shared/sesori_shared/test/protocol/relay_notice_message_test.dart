import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RelayNoticeMessage", () {
    test("decodes bridge_connected with a bridge id", () {
      final message = RelayNoticeMessage.fromJson({"type": "bridge_connected", "bridgeId": "br_abc12345"});

      expect(message, const RelayNoticeMessage.bridgeConnected(bridgeId: "br_abc12345"));
    });

    test("decodes bridge_connected from an older relay without a bridge id", () {
      final message = RelayNoticeMessage.fromJson({"type": "bridge_connected"});

      expect(message, const RelayNoticeMessage.bridgeConnected(bridgeId: null));
    });

    test("decodes bridge_disconnected with and without a bridge id", () {
      expect(
        RelayNoticeMessage.fromJson({"type": "bridge_disconnected", "bridgeId": "br_abc12345"}),
        const RelayNoticeMessage.bridgeDisconnected(bridgeId: "br_abc12345"),
      );
      expect(
        RelayNoticeMessage.fromJson({"type": "bridge_disconnected"}),
        const RelayNoticeMessage.bridgeDisconnected(bridgeId: null),
      );
    });

    test("decodes bridge_presence", () {
      expect(
        RelayNoticeMessage.fromJson({"type": "bridge_presence", "bridgeId": "br_abc12345", "online": true}),
        const RelayNoticeMessage.bridgePresence(bridgeId: "br_abc12345", online: true),
      );
      expect(
        RelayNoticeMessage.fromJson({"type": "bridge_presence", "bridgeId": "br_abc12345", "online": false}),
        const RelayNoticeMessage.bridgePresence(bridgeId: "br_abc12345", online: false),
      );
    });

    test("decodes an unknown type to the fallback instead of throwing", () {
      final message = RelayNoticeMessage.fromJson({"type": "bridge_renamed", "bridgeId": "br_abc12345"});

      expect(message, isA<UnknownRelayNoticeMessage>());
    });
  });
}
