import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("BaseBranchResponse", () {
    test("round-trips baseBranch and repoSlug through JSON", () {
      const response = BaseBranchResponse(baseBranch: "main", repoSlug: "org/repo");

      final decoded = BaseBranchResponse.fromJson(response.toJson());

      expect(decoded, equals(response));
    });

    test("decodes a payload without repoSlug to null (older bridges omit it)", () {
      final decoded = BaseBranchResponse.fromJson({"baseBranch": "main"});

      expect(decoded.baseBranch, equals("main"));
      expect(decoded.repoSlug, isNull);
    });

    test("decodes explicit nulls", () {
      final decoded = BaseBranchResponse.fromJson({"baseBranch": null, "repoSlug": null});

      expect(decoded.baseBranch, isNull);
      expect(decoded.repoSlug, isNull);
    });
  });
}
