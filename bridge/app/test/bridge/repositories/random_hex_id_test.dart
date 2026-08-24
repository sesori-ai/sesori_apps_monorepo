import "dart:math";

import "package:sesori_bridge/src/repositories/random_hex_id.dart";
import "package:test/test.dart";

void main() {
  test("generates requested prefix and hexadecimal bytes", () {
    final sessionId = generateRandomHexId(
      secureRandom: Random(1),
      prefix: "ses_",
      byteLength: 16,
    );
    final promptId = generateRandomHexId(
      secureRandom: Random(1),
      prefix: "prm_",
      byteLength: 16,
    );

    expect(sessionId, matches(RegExp(r"^ses_[0-9a-f]{32}$")));
    expect(promptId, matches(RegExp(r"^prm_[0-9a-f]{32}$")));
  });
}
