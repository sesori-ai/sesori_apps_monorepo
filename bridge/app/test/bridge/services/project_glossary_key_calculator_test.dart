import "package:sesori_bridge/src/services/project_glossary_key_calculator.dart";
import "package:test/test.dart";

void main() {
  const calculator = ProjectGlossaryKeyCalculator();
  final secret = List<int>.generate(32, (index) => index);

  test("derives a deterministic opaque bridge/project HMAC key", () {
    final key = calculator.calculate(
      secret: secret,
      bridgeId: "br_test1234",
      projectId: "project-123",
    );

    expect(key, "prj_v1_XAVcFCqShkey3n-XbI01cR2MGr6wvmvx8RPGVLl2jQE");
    expect(key, isNot(contains("br_test1234")));
    expect(key, isNot(contains("project-123")));
    expect(
      calculator.calculate(secret: secret, bridgeId: "br_other", projectId: "project-123"),
      isNot(key),
    );
    expect(
      calculator.calculate(
        secret: List<int>.filled(32, 255),
        bridgeId: "br_test1234",
        projectId: "project-123",
      ),
      isNot(key),
    );
  });

  test("rejects short secrets and empty identifiers", () {
    expect(
      () => calculator.calculate(secret: const [1, 2, 3], bridgeId: "bridge", projectId: "project"),
      throwsArgumentError,
    );
    expect(
      () => calculator.calculate(secret: secret, bridgeId: "", projectId: "project"),
      throwsArgumentError,
    );
    expect(
      () => calculator.calculate(secret: secret, bridgeId: "bridge", projectId: ""),
      throwsArgumentError,
    );
  });
}
