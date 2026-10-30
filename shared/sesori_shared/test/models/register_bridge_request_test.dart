import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RegisterBridgeRequest", () {
    test("omits bridgeId from JSON when null", () {
      const request = RegisterBridgeRequest(
        name: "alex-macbook",
        platform: "macos",
        bridgeId: null,
        hostKey: null,
        kind: BridgeKind.desktop,
      );

      final json = request.toJson();

      expect(json, equals({"name": "alex-macbook", "platform": "macos", "kind": "desktop"}));
    });

    test("includes bridgeId in JSON when set", () {
      const request = RegisterBridgeRequest(
        name: "alex-macbook",
        platform: "macos",
        bridgeId: "br_abc12345",
        hostKey: null,
        kind: BridgeKind.cli,
      );

      final json = request.toJson();

      expect(
        json,
        equals({
          "name": "alex-macbook",
          "platform": "macos",
          "bridgeId": "br_abc12345",
          "kind": "cli",
        }),
      );
    });

    test("includes hostKey in JSON when set", () {
      const request = RegisterBridgeRequest(
        name: "alex-macbook",
        platform: "macos",
        bridgeId: null,
        hostKey: _hostKey,
        kind: BridgeKind.cli,
      );

      expect(
        request.toJson(),
        equals({"name": "alex-macbook", "platform": "macos", "hostKey": _hostKey, "kind": "cli"}),
      );
    });

    test("parses a body without bridgeId", () {
      final request = RegisterBridgeRequest.fromJson({
        "name": "alex-macbook",
        "platform": "linux",
        "kind": "cli",
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
        "kind": "cli",
      });

      expect(request.bridgeId, equals("br_abc12345"));
    });

    test("round-trips through JSON", () {
      const original = RegisterBridgeRequest(
        name: "alex-macbook",
        platform: "windows",
        bridgeId: "br_abc12345",
        hostKey: _hostKey,
        kind: BridgeKind.cli,
      );

      final restored = RegisterBridgeRequest.fromJson(original.toJson());

      expect(restored, equals(original));
    });
  });
}

const _hostKey = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
