import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("derives the canonical opaque project glossary key", () {
    final key = deriveProjectGlossaryKey(projectId: "project-123");

    expect(key, "prj_v1_xgjNDm_yyduAKisFHr498ZgcjIU1FACdyEj68wSmbhc");
    expect(key, isNot(contains("project-123")));
  });

  test("rejects an empty project identifier", () {
    expect(() => deriveProjectGlossaryKey(projectId: ""), throwsArgumentError);
  });

  test("validates only opaque v1 project glossary keys", () {
    expect(isValidProjectGlossaryKey(value: "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"), isTrue);
    expect(isValidProjectGlossaryKey(value: "project-123"), isFalse);
    expect(isValidProjectGlossaryKey(value: "prj_v1_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa="), isFalse);
    expect(isValidProjectGlossaryKey(value: "prj_v2_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"), isFalse);
  });
}
