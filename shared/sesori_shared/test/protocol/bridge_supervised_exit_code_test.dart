import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("maps every supervised bridge exit code from its process value", () {
    for (final BridgeSupervisedExitCode value in BridgeSupervisedExitCode.values) {
      expect(
        BridgeSupervisedExitCode.fromCode(code: value.code),
        same(value),
      );
    }
  });

  test("leaves ordinary crash codes outside the deliberate contract", () {
    expect(BridgeSupervisedExitCode.fromCode(code: 42), isNull);
  });
}
