import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  final key = ProjectGlossaryKey.parse(value: "prj_v1_${List.filled(43, "A").join()}");

  test("serializes repository scope without bridge ownership", () {
    final request = ProjectGlossaryWordsRequest(projectKey: key, bridgeId: null, words: const ["Sesori"]);

    expect(request.toJson(), {
      "projectKey": key.value,
      "words": ["Sesori"],
    });
    expect(ProjectGlossaryWordsRequest.fromJson(request.toJson()), request);
  });

  test("serializes bridge ownership for a local scope", () {
    final request = ProjectGlossaryWordsRequest(
      projectKey: key,
      bridgeId: "br_bridge0001",
      words: const ["Sesori", "XChaCha20"],
    );

    expect(request.toJson(), {
      "projectKey": key.value,
      "bridgeId": "br_bridge0001",
      "words": ["Sesori", "XChaCha20"],
    });
    expect(ProjectGlossaryWordsRequest.fromJson(request.toJson()), request);
  });

  test("rejects an invalid persisted key", () {
    expect(
      () => ProjectGlossaryWordsRequest.fromJson({
        "projectKey": "invalid",
        "words": ["Sesori"],
      }),
      throwsFormatException,
    );
  });
}
