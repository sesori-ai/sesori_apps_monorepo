import "package:test/test.dart";
import "package:sesori_shared/sesori_shared.dart";

void main() {
  group("PullRequestInfo", () {
    test("creates instance with all required fields", () {
      final pr = PullRequestInfo(
        number: 42,
        url: "https://github.com/org/repo/pull/42",
        title: "Add feature X",
        state: "open",
        mergeableStatus: "mergeable",
        reviewDecision: "approved",
        checkStatus: "success",
      );

      expect(pr.number, 42);
      expect(pr.url, "https://github.com/org/repo/pull/42");
      expect(pr.title, "Add feature X");
      expect(pr.state, "open");
      expect(pr.mergeableStatus, "mergeable");
      expect(pr.reviewDecision, "approved");
      expect(pr.checkStatus, "success");
    });

    test("creates instance with nullable fields as null", () {
      final pr = PullRequestInfo(
        number: 1,
        url: "https://github.com/org/repo/pull/1",
        title: "Test PR",
        state: "draft",
        mergeableStatus: null,
        reviewDecision: null,
        checkStatus: null,
      );

      expect(pr.number, 1);
      expect(pr.mergeableStatus, isNull);
      expect(pr.reviewDecision, isNull);
      expect(pr.checkStatus, isNull);
    });

    test("serializes to JSON correctly", () {
      final pr = PullRequestInfo(
        number: 99,
        url: "https://example.com/pr/99",
        title: "Test",
        state: "closed",
        mergeableStatus: "conflicted",
        reviewDecision: "changes_requested",
        checkStatus: "failure",
      );

      final json = pr.toJson();

      expect(json["number"], 99);
      expect(json["url"], "https://example.com/pr/99");
      expect(json["title"], "Test");
      expect(json["state"], "closed");
      expect(json["mergeableStatus"], "conflicted");
      expect(json["reviewDecision"], "changes_requested");
      expect(json["checkStatus"], "failure");
    });

    test("deserializes from JSON correctly", () {
      final json = {
        "number": 55,
        "url": "https://github.com/test/repo/pull/55",
        "title": "Deserialize test",
        "state": "open",
        "mergeableStatus": "mergeable",
        "reviewDecision": "approved",
        "checkStatus": "success",
      };

      final pr = PullRequestInfo.fromJson(json);

      expect(pr.number, 55);
      expect(pr.url, "https://github.com/test/repo/pull/55");
      expect(pr.title, "Deserialize test");
      expect(pr.state, "open");
      expect(pr.mergeableStatus, "mergeable");
      expect(pr.reviewDecision, "approved");
      expect(pr.checkStatus, "success");
    });

    test("deserializes from JSON with null optional fields", () {
      final json = {
        "number": 10,
        "url": "https://example.com/pr/10",
        "title": "Minimal PR",
        "state": "open",
        "mergeableStatus": null,
        "reviewDecision": null,
        "checkStatus": null,
      };

      final pr = PullRequestInfo.fromJson(json);

      expect(pr.number, 10);
      expect(pr.mergeableStatus, isNull);
      expect(pr.reviewDecision, isNull);
      expect(pr.checkStatus, isNull);
    });

    test("supports equality comparison", () {
      final pr1 = PullRequestInfo(
        number: 1,
        url: "https://example.com/pr/1",
        title: "Same PR",
        state: "open",
        mergeableStatus: "mergeable",
        reviewDecision: null,
        checkStatus: "success",
      );

      final pr2 = PullRequestInfo(
        number: 1,
        url: "https://example.com/pr/1",
        title: "Same PR",
        state: "open",
        mergeableStatus: "mergeable",
        reviewDecision: null,
        checkStatus: "success",
      );

      final pr3 = PullRequestInfo(
        number: 2,
        url: "https://example.com/pr/2",
        title: "Different PR",
        state: "closed",
        mergeableStatus: null,
        reviewDecision: "approved",
        checkStatus: "failure",
      );

      expect(pr1, pr2);
      expect(pr1, isNot(pr3));
    });
  });
}
