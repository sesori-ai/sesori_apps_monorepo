import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("serializes the strict project glossary mutation body", () {
    const request = ProjectGlossaryWordsRequest(
      projectKey: "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      words: ["Sesori", "XChaCha20-Poly1305"],
    );

    expect(request.toJson(), {
      "projectKey": "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      "words": ["Sesori", "XChaCha20-Poly1305"],
    });
    expect(ProjectGlossaryWordsRequest.fromJson(request.toJson()), request);
  });
}
