import "package:pi_plugin/pi_plugin.dart";
import "package:test/test.dart";

void main() {
  group("PiThinkingLevel", () {
    test("round-trips every supported wire value", () {
      expect(
        PiThinkingLevel.values.map((level) => level.wireValue),
        ["off", "minimal", "low", "medium", "high", "xhigh", "max"],
      );
      for (final level in PiThinkingLevel.values) {
        expect(PiThinkingLevel.tryParse(level.wireValue), level);
      }
    });

    test("fails soft for absent and unknown levels", () {
      expect(PiThinkingLevel.tryParse(null), isNull);
      expect(PiThinkingLevel.tryParse("future"), isNull);
      expect(PiThinkingLevel.tryParse(" high "), PiThinkingLevel.high);
    });
  });
}
