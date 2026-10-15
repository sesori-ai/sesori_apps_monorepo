import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:test/test.dart";

void main() {
  group("ServerConnectionConfig", () {
    test("can be constructed with relayHost and authToken", () {
      const config = ServerConnectionConfig(
        relayHost: "relay.sesori.com",
        authToken: "Bearer eyJhbGci...",
        bridgeId: null,
      );

      expect(config.relayHost, equals("relay.sesori.com"));
      expect(config.authToken, equals("Bearer eyJhbGci..."));
    });

    test("authToken intent is explicit when disconnected", () {
      const config = ServerConnectionConfig(relayHost: "relay.sesori.com", authToken: null, bridgeId: null);

      expect(config.relayHost, equals("relay.sesori.com"));
      expect(config.authToken, isNull);
    });

    test("two configs with same fields are equal", () {
      const a = ServerConnectionConfig(relayHost: "relay.sesori.com", authToken: "tok", bridgeId: null);
      const b = ServerConnectionConfig(relayHost: "relay.sesori.com", authToken: "tok", bridgeId: null);

      expect(a, equals(b));
    });

    test("two configs with different relayHost are not equal", () {
      const a = ServerConnectionConfig(relayHost: "relay.sesori.com", authToken: null, bridgeId: null);
      const b = ServerConnectionConfig(relayHost: "other.sesori.com", authToken: null, bridgeId: null);

      expect(a, isNot(equals(b)));
    });
  });
}
