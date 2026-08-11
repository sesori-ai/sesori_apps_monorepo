import "package:pi_plugin/pi_testing.dart";
import "package:test/test.dart";

void main() {
  test("builds Pi response and event envelopes", () {
    expect(
      piSuccessResponseFixture(id: "1", command: "get_state", data: const {"isStreaming": false}),
      {
        "id": "1",
        "type": "response",
        "command": "get_state",
        "success": true,
        "data": {"isStreaming": false},
      },
    );
    expect(piFailureResponseFixture(id: "2", command: "set_model", error: "unavailable"), {
      "id": "2",
      "type": "response",
      "command": "set_model",
      "success": false,
      "error": "unavailable",
    });
    expect(piEventFixture(type: "agent_start", fields: const {"sequence": 3}), {
      "type": "agent_start",
      "sequence": 3,
    });
  });
}
