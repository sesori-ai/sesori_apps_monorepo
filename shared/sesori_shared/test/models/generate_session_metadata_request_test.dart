import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("GenerateSessionMetadataRequest round-trips firstMessage", () {
    const request = GenerateSessionMetadataRequest(firstMessage: "Create login flow");

    expect(request.toJson(), equals({"firstMessage": "Create login flow"}));
    expect(GenerateSessionMetadataRequest.fromJson(request.toJson()), equals(request));
  });
}
