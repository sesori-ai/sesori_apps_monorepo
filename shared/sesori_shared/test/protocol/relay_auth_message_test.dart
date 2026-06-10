import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RelayMessage.auth bridgeId", () {
    test("omits bridgeId from JSON when null", () {
      const msg = RelayMessage.auth(token: "jwt-token", role: "bridge", bridgeId: null);

      final json = msg.toJson();

      expect(json, equals({"type": "auth", "token": "jwt-token", "role": "bridge"}));
    });

    test("includes bridgeId in JSON when set", () {
      const msg = RelayMessage.auth(
        token: "jwt-token",
        role: "bridge",
        bridgeId: "br_abc12345",
      );

      final json = msg.toJson();

      expect(
        json,
        equals({
          "type": "auth",
          "token": "jwt-token",
          "role": "bridge",
          "bridgeId": "br_abc12345",
        }),
      );
    });

    test("parses auth message without bridgeId", () {
      final msg = RelayMessage.fromJson({
        "type": "auth",
        "token": "jwt-token",
        "role": "phone",
      });

      expect(msg, isA<AuthRelayMessage>());
      expect((msg as AuthRelayMessage).bridgeId, isNull);
    });

    test("parses auth message with bridgeId", () {
      final msg = RelayMessage.fromJson({
        "type": "auth",
        "token": "jwt-token",
        "role": "bridge",
        "bridgeId": "br_abc12345",
      });

      expect(msg, isA<AuthRelayMessage>());
      expect((msg as AuthRelayMessage).bridgeId, equals("br_abc12345"));
    });
  });
}
