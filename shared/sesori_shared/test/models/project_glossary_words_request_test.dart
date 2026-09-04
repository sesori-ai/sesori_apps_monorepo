import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  final key = ProjectGlossaryKey.parse(value: "prj_v1_${List.filled(43, "A").join()}");

  test("serializes the repository scope variant", () {
    final request = ProjectGlossaryWordsRequest(
      scope: ProjectGlossaryScope.repository(projectKey: key),
      words: const ["Sesori"],
    );

    expect(request.toJson(), {
      "scope": {"type": "repository", "projectKey": key.value},
      "words": ["Sesori"],
    });
    expect(ProjectGlossaryWordsRequest.fromJson(request.toJson()), request);
  });

  test("serializes the bridge-local scope with required ownership", () {
    final request = ProjectGlossaryWordsRequest(
      scope: ProjectGlossaryScope.bridgeLocal(projectKey: key, bridgeId: "br_bridge0001"),
      words: const ["Sesori", "XChaCha20"],
    );

    expect(request.toJson(), {
      "scope": {"type": "bridge_local", "projectKey": key.value, "bridgeId": "br_bridge0001"},
      "words": ["Sesori", "XChaCha20"],
    });
    expect(ProjectGlossaryWordsRequest.fromJson(request.toJson()), request);
  });

  test("rejects incomplete and legacy scope shapes", () {
    final invalid = [
      {
        "scope": {"type": "bridge_local", "projectKey": key.value},
        "words": ["Sesori"],
      },
      {
        "projectKey": key.value,
        "bridgeId": "br_bridge0001",
        "words": ["Sesori"],
      },
      {
        "scope": {"type": "unknown", "projectKey": key.value},
        "words": ["Sesori"],
      },
    ];

    for (final json in invalid) {
      expect(() => ProjectGlossaryWordsRequest.fromJson(json), throwsA(anything));
    }
  });

  test("rejects an invalid persisted key", () {
    expect(
      () => ProjectGlossaryWordsRequest.fromJson({
        "scope": {"type": "repository", "projectKey": "invalid"},
        "words": ["Sesori"],
      }),
      throwsFormatException,
    );
  });
}
