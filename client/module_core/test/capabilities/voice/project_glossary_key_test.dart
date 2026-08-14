import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  test("Given a project id When deriving glossary key Then returns the canonical opaque vector", () {
    final key = deriveProjectGlossaryKey("project-123");

    expect(key, "prj_v1_xgjNDm_yyduAKisFHr498ZgcjIU1FACdyEj68wSmbhc");
    expect(key, isNot(contains("project-123")));
  });

  test("Given candidate keys When validating project glossary key shape Then accepts only opaque v1 keys", () {
    expect(isValidProjectGlossaryKey("prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"), isTrue);
    expect(isValidProjectGlossaryKey("project-123"), isFalse);
    expect(isValidProjectGlossaryKey("prj_v1_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa="), isFalse);
    expect(isValidProjectGlossaryKey("prj_v2_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"), isFalse);
  });
}
