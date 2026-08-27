import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  final secret = List<int>.generate(32, (index) => index);

  test("derives the canonical bridge-namespaced opaque project glossary key", () {
    final key = deriveProjectGlossaryKey(
      secret: secret,
      bridgeId: "br_test1234",
      projectId: "project-123",
    );

    expect(key, "prj_v1_XAVcFCqShkey3n-XbI01cR2MGr6wvmvx8RPGVLl2jQE");
    expect(key, isNot(contains("br_test1234")));
    expect(key, isNot(contains("project-123")));
    expect(
      deriveProjectGlossaryKey(secret: secret, bridgeId: "br_other", projectId: "project-123"),
      isNot(key),
    );
    expect(
      deriveProjectGlossaryKey(
        secret: List<int>.filled(32, 255),
        bridgeId: "br_test1234",
        projectId: "project-123",
      ),
      isNot(key),
    );
  });

  test("rejects short secrets and empty identifiers", () {
    expect(
      () => deriveProjectGlossaryKey(secret: const [1, 2, 3], bridgeId: "bridge", projectId: "project"),
      throwsArgumentError,
    );
    expect(
      () => deriveProjectGlossaryKey(secret: secret, bridgeId: "", projectId: "project-123"),
      throwsArgumentError,
    );
    expect(
      () => deriveProjectGlossaryKey(secret: secret, bridgeId: "br_test1234", projectId: ""),
      throwsArgumentError,
    );
  });

  test("validates only opaque v1 project glossary keys", () {
    expect(isValidProjectGlossaryKey(value: "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"), isTrue);
    expect(isValidProjectGlossaryKey(value: "project-123"), isFalse);
    expect(isValidProjectGlossaryKey(value: "prj_v1_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa="), isFalse);
    expect(isValidProjectGlossaryKey(value: "prj_v2_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"), isFalse);
  });
}
