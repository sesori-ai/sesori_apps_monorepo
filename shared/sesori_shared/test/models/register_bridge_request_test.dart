import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RegisterBridgeRequest", () {
    test("omits bridgeId from JSON when null", () {
      const request = RegisterBridgeRequest(name: "alex-macbook", platform: "macos", bridgeId: null, hostKey: null);

      final json = request.toJson();

      expect(json, equals({"name": "alex-macbook", "platform": "macos"}));
    });

    test("includes bridgeId in JSON when set", () {
      const request = RegisterBridgeRequest(
        name: "alex-macbook",
        platform: "macos",
        bridgeId: "br_abc12345",
        hostKey: null,
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

    test("includes hostKey in JSON when set", () {
      const request = RegisterBridgeRequest(
        name: "alex-macbook",
        platform: "macos",
        bridgeId: null,
        hostKey: _hostKey,
      );

      expect(request.toJson(), equals({"name": "alex-macbook", "platform": "macos", "hostKey": _hostKey}));
    });

    test("parses a body without bridgeId", () {
      final request = RegisterBridgeRequest.fromJson({
        "name": "alex-macbook",
        "platform": "linux",
      });

      expect(request.name, equals("alex-macbook"));
      expect(request.platform, equals("linux"));
      expect(request.bridgeId, isNull);
      expect(request.hostKey, isNull);
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
        hostKey: _hostKey,
      );

      final restored = RegisterBridgeRequest.fromJson(original.toJson());

      expect(restored, equals(original));
    });
  });
}

const _hostKey = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
