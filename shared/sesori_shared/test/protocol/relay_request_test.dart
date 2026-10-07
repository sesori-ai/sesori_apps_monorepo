import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RelayMessage.request", () {
    test("decodes a released app's request without the deflate key as plain", () {
      final message = RelayMessage.fromJson({
        "type": "request",
        "id": "request-1",
        "method": "GET",
        "path": "/global/health",
        "headers": <String, String>{},
      });

      expect(message, isA<RelayRequest>().having((r) => r.acceptsDeflatedResponse, "acceptsDeflatedResponse", isFalse));
    });

    test("round-trips the deflate ask", () {
      const message = RelayMessage.request(
        id: "request-1",
        method: "POST",
        path: "/session/messages",
        headers: {},
        body: "{}",
        acceptsDeflatedResponse: true,
      );

      final json = message.toJson();

      expect(json["acceptsDeflatedResponse"], isTrue);
      expect(RelayMessage.fromJson(json), message);
    });
  });
}
