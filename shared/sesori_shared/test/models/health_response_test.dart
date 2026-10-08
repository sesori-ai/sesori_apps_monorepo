import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("HealthResponse.bridgeKind", () {
    Map<String, dynamic> payload({required Object? bridgeKind}) => {
      "healthy": true,
      "version": "1.9.1",
      "filesystemAccessDegraded": false,
      "bridgeKind": ?bridgeKind,
    };

    test("round-trips a desktop bridge through JSON", () {
      const response = HealthResponse(
        healthy: true,
        version: "1.9.1",
        filesystemAccessDegraded: false,
        bridgeKind: BridgeKind.desktop,
      );

      final json = response.toJson();

      expect(json["bridgeKind"], "desktop");
      expect(HealthResponse.fromJson(json), response);
    });

    test("decodes cli", () {
      expect(HealthResponse.fromJson(payload(bridgeKind: "cli")).bridgeKind, BridgeKind.cli);
    });

    test("a bridge that omits the field is a command-line bridge", () {
      expect(HealthResponse.fromJson(payload(bridgeKind: null)).bridgeKind, BridgeKind.cli);
    });

    test("an unrecognised kind from a newer bridge falls back to cli", () {
      expect(HealthResponse.fromJson(payload(bridgeKind: "server")).bridgeKind, BridgeKind.cli);
    });
  });
}
