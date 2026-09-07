import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("older empty abort success defaults to legacy descendant fanout", () {
    expect(SessionAbortResponse.fromJson(const {}).subAgentsHandled, isFalse);
  });

  test("round-trips plugin-owned descendant handling", () {
    const response = SessionAbortResponse(subAgentsHandled: true);

    expect(SessionAbortResponse.fromJson(response.toJson()), response);
  });
}
