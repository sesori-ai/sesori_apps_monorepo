import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("serializes the bridge-derived project glossary key", () {
    const response = PopulateProjectVoiceGlossaryResponse(
      projectKey: "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    );

    expect(response.toJson(), {
      "projectKey": "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    });
    expect(PopulateProjectVoiceGlossaryResponse.fromJson(response.toJson()), response);
  });
}
