import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("older empty abort success defaults to legacy descendant fanout", () {
    final response = SessionAbortResponse.fromJson(const {});

    expect(response.subAgentsHandled, isFalse);
    expect(response.handledSubAgentSessionIds, isEmpty);
  });

  test("round-trips plugin-owned descendant handling", () {
    const response = SessionAbortResponse(
      subAgentsHandled: false,
      handledSubAgentSessionIds: ["handled-child"],
    );

    expect(SessionAbortResponse.fromJson(response.toJson()), response);
  });
}
