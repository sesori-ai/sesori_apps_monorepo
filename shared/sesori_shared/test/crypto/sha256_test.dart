import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("calculates the standard SHA-256 vector", () async {
    final digest = await calculateSha256(message: utf8.encode("abc"));

    expect(
      digest.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join(),
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    );
  });
}
