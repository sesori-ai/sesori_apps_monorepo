import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("GenerateSessionMetadataRequest round-trips firstMessage and bridgeId", () {
    const request = GenerateSessionMetadataRequest(firstMessage: "Create login flow", bridgeId: "br_abc12345");

    expect(request.toJson(), equals({"firstMessage": "Create login flow", "bridgeId": "br_abc12345"}));
    expect(GenerateSessionMetadataRequest.fromJson(request.toJson()), equals(request));
  });

  test("GenerateSessionMetadataRequest omits a null bridgeId", () {
    const request = GenerateSessionMetadataRequest(firstMessage: "Create login flow", bridgeId: null);

    expect(request.toJson(), equals({"firstMessage": "Create login flow"}));
  });
}
