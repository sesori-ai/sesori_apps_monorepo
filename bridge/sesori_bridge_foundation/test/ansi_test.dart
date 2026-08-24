import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  test("strips CSI color sequences", () {
    expect(stripAnsi(value: "\x1B[31mfailed\x1B[0m"), "failed");
  });

  test("strips OSC hyperlinks terminated by BEL", () {
    expect(stripAnsi(value: "\x1B]8;;https://example.test\x07label\x1B]8;;\x07"), "label");
  });

  test("strips OSC sequences terminated by string terminator", () {
    expect(stripAnsi(value: "before\x1B]0;secret title\x1B\\after"), "beforeafter");
  });
}
