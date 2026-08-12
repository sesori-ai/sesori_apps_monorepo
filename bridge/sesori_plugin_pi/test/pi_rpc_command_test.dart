import "package:pi_plugin/pi_plugin.dart";
import "package:test/test.dart";

void main() {
  test("round-trips every Pi RPC command wire value without duplicates", () {
    final wireValues = PiRpcCommand.values.map((command) => command.wireValue).toList();

    expect(wireValues.toSet(), hasLength(wireValues.length));
    for (final command in PiRpcCommand.values) {
      expect(PiRpcCommand.tryParse(value: command.wireValue), command);
    }
    expect(PiRpcCommand.tryParse(value: "future_command"), isNull);
  });
}
