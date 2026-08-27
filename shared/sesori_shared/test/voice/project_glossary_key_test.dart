import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("derives the canonical bridge-namespaced opaque project glossary key", () {
    final key = deriveProjectGlossaryKey(bridgeId: "br_test1234", projectId: "project-123");

    expect(key, "prj_v1_Tv-knO6tUf4aqThj97EB1CAcIWOkebUbT-FvTQdxwVY");
    expect(key, isNot(contains("br_test1234")));
    expect(key, isNot(contains("project-123")));
    expect(
      deriveProjectGlossaryKey(bridgeId: "br_other", projectId: "project-123"),
      isNot(key),
    );
  });

  test("rejects empty bridge and project identifiers", () {
    expect(() => deriveProjectGlossaryKey(bridgeId: "", projectId: "project-123"), throwsArgumentError);
    expect(() => deriveProjectGlossaryKey(bridgeId: "br_test1234", projectId: ""), throwsArgumentError);
  });

  test("validates only opaque v1 project glossary keys", () {
    expect(isValidProjectGlossaryKey(value: "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"), isTrue);
    expect(isValidProjectGlossaryKey(value: "project-123"), isFalse);
    expect(isValidProjectGlossaryKey(value: "prj_v1_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa="), isFalse);
    expect(isValidProjectGlossaryKey(value: "prj_v2_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"), isFalse);
  });
}
