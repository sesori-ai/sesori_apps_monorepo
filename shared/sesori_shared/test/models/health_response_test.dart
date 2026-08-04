import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("defaults dedicated command event support for the public v1.6.0 bridge", () {
    final response = HealthResponse.fromJson({
      "healthy": true,
      "version": "1.6.0",
      "filesystemAccessDegraded": false,
    });

    expect(response.supportsSessionCommandsUpdated, isFalse);
  });

  test("round-trips dedicated command event support", () {
    const response = HealthResponse(
      healthy: true,
      version: "1.7.0",
      filesystemAccessDegraded: false,
      supportsSessionCommandsUpdated: true,
    );

    expect(HealthResponse.fromJson(response.toJson()), response);
  });
}
