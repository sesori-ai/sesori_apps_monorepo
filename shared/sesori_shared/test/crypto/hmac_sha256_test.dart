import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("calculates the RFC 4231 HMAC-SHA-256 vector", () async {
    final digest = await calculateHmacSha256(
      secret: List<int>.filled(20, 0x0b),
      message: utf8.encode("Hi There"),
    );

    expect(
      digest.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join(),
      "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7",
    );
  });
}
