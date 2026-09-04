import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  final validValue = "prj_v1_${List.filled(43, "A").join()}";

  test("parses the opaque glossary key format", () {
    final key = ProjectGlossaryKey.parse(value: validValue);

    expect(key.value, validValue);
    expect(ProjectGlossaryKey.tryParse(value: validValue), key);
  });

  test("rejects malformed or non-url-safe keys", () {
    expect(ProjectGlossaryKey.tryParse(value: "prj_v1_short"), isNull);
    expect(ProjectGlossaryKey.tryParse(value: "prj_v1_${List.filled(43, "+").join()}"), isNull);
    expect(() => ProjectGlossaryKey.parse(value: "secret material"), throwsFormatException);
  });
}
