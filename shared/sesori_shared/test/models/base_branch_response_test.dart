import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("BaseBranchResponse", () {
    test("round-trips baseBranch, repoSlug and repoHost through JSON", () {
      const response = BaseBranchResponse(
        baseBranch: "main",
        repoSlug: "org/repo",
        repoHost: "github.com",
      );

      final decoded = BaseBranchResponse.fromJson(response.toJson());

      expect(decoded, equals(response));
    });

    test("decodes a payload without repoSlug/repoHost to nulls (older bridges omit them)", () {
      final decoded = BaseBranchResponse.fromJson({"baseBranch": "main"});

      expect(decoded.baseBranch, equals("main"));
      expect(decoded.repoSlug, isNull);
      expect(decoded.repoHost, isNull);
    });

    test("decodes explicit nulls", () {
      final decoded = BaseBranchResponse.fromJson({
        "baseBranch": null,
        "repoSlug": null,
        "repoHost": null,
      });

      expect(decoded.baseBranch, isNull);
      expect(decoded.repoSlug, isNull);
      expect(decoded.repoHost, isNull);
    });
  });
}
