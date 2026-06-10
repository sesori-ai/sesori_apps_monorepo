import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RegisterBridgeRequest", () {
    test("omits bridgeId from JSON when null", () {
      const request = RegisterBridgeRequest(name: "alex-macbook", platform: "macos", bridgeId: null);

      final json = request.toJson();

      expect(json, equals({"name": "alex-macbook", "platform": "macos"}));
    });

    test("includes bridgeId in JSON when set", () {
      const request = RegisterBridgeRequest(
        name: "alex-macbook",
        platform: "macos",
        bridgeId: "br_abc12345",
      );

      final json = request.toJson();

      expect(
        json,
        equals({
          "name": "alex-macbook",
          "platform": "macos",
          "bridgeId": "br_abc12345",
        }),
      );
    });

    test("parses a body without bridgeId", () {
      final request = RegisterBridgeRequest.fromJson({
        "name": "alex-macbook",
        "platform": "linux",
      });

      expect(request.name, equals("alex-macbook"));
      expect(request.platform, equals("linux"));
      expect(request.bridgeId, isNull);
    });

    test("parses a body with bridgeId", () {
      final request = RegisterBridgeRequest.fromJson({
        "name": "alex-macbook",
        "platform": "linux",
        "bridgeId": "br_abc12345",
      });

      expect(request.bridgeId, equals("br_abc12345"));
    });

    test("round-trips through JSON", () {
      const original = RegisterBridgeRequest(
        name: "alex-macbook",
        platform: "windows",
        bridgeId: "br_abc12345",
      );

      final restored = RegisterBridgeRequest.fromJson(original.toJson());

      expect(restored, equals(original));
    });
  });
}
