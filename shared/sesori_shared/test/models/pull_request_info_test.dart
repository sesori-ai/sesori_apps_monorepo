import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PullRequestInfo", () {
    test("creates instance with all required fields", () {
      const pr = PullRequestInfo(
        number: 42,
        url: "https://github.com/org/repo/pull/42",
        title: "Add feature X",
        state: PrState.open,
        mergeableStatus: PrMergeableStatus.mergeable,
        reviewDecision: PrReviewDecision.approved,
        checkStatus: PrCheckStatus.success,
      );

      expect(pr.number, 42);
      expect(pr.url, "https://github.com/org/repo/pull/42");
      expect(pr.title, "Add feature X");
      expect(pr.state, PrState.open);
      expect(pr.mergeableStatus, PrMergeableStatus.mergeable);
      expect(pr.reviewDecision, PrReviewDecision.approved);
      expect(pr.checkStatus, PrCheckStatus.success);
    });

    test("creates instance with unknown enum values", () {
      const pr = PullRequestInfo(
        number: 1,
        url: "https://github.com/org/repo/pull/1",
        title: "Test PR",
        state: PrState.unknown,
        mergeableStatus: PrMergeableStatus.unknown,
        reviewDecision: PrReviewDecision.unknown,
        checkStatus: PrCheckStatus.unknown,
      );

      expect(pr.number, 1);
      expect(pr.state, PrState.unknown);
      expect(pr.mergeableStatus, PrMergeableStatus.unknown);
      expect(pr.reviewDecision, PrReviewDecision.unknown);
      expect(pr.checkStatus, PrCheckStatus.unknown);
    });

    test("serializes to JSON correctly", () {
      const pr = PullRequestInfo(
        number: 99,
        url: "https://example.com/pr/99",
        title: "Test",
        state: PrState.closed,
        mergeableStatus: PrMergeableStatus.conflicting,
        reviewDecision: PrReviewDecision.changesRequested,
        checkStatus: PrCheckStatus.failure,
      );

      final json = pr.toJson();

      expect(json["number"], 99);
      expect(json["url"], "https://example.com/pr/99");
      expect(json["title"], "Test");
      expect(json["state"], "CLOSED");
      expect(json["mergeableStatus"], "CONFLICTING");
      expect(json["reviewDecision"], "CHANGES_REQUESTED");
      expect(json["checkStatus"], "FAILURE");
    });

    test("deserializes from JSON correctly", () {
      final json = {
        "number": 55,
        "url": "https://github.com/test/repo/pull/55",
        "title": "Deserialize test",
        "state": "OPEN",
        "mergeableStatus": "MERGEABLE",
        "reviewDecision": "APPROVED",
        "checkStatus": "SUCCESS",
      };

      final pr = PullRequestInfo.fromJson(json);

      expect(pr.number, 55);
      expect(pr.url, "https://github.com/test/repo/pull/55");
      expect(pr.title, "Deserialize test");
      expect(pr.state, PrState.open);
      expect(pr.mergeableStatus, PrMergeableStatus.mergeable);
      expect(pr.reviewDecision, PrReviewDecision.approved);
      expect(pr.checkStatus, PrCheckStatus.success);
    });

    test("deserializes from JSON with unknown enum values", () {
      final json = {
        "number": 10,
        "url": "https://example.com/pr/10",
        "title": "Minimal PR",
        "state": "UNKNOWN_STATE",
        "mergeableStatus": "UNKNOWN_STATUS",
        "reviewDecision": "UNKNOWN_DECISION",
        "checkStatus": "UNKNOWN_CHECK",
      };

      final pr = PullRequestInfo.fromJson(json);

      expect(pr.number, 10);
      expect(pr.state, PrState.unknown);
      expect(pr.mergeableStatus, PrMergeableStatus.unknown);
      expect(pr.reviewDecision, PrReviewDecision.unknown);
      expect(pr.checkStatus, PrCheckStatus.unknown);
    });

    test("supports equality comparison", () {
      const pr1 = PullRequestInfo(
        number: 1,
        url: "https://example.com/pr/1",
        title: "Same PR",
        state: PrState.open,
        mergeableStatus: PrMergeableStatus.mergeable,
        reviewDecision: PrReviewDecision.unknown,
        checkStatus: PrCheckStatus.success,
      );

      const pr2 = PullRequestInfo(
        number: 1,
        url: "https://example.com/pr/1",
        title: "Same PR",
        state: PrState.open,
        mergeableStatus: PrMergeableStatus.mergeable,
        reviewDecision: PrReviewDecision.unknown,
        checkStatus: PrCheckStatus.success,
      );

      const pr3 = PullRequestInfo(
        number: 2,
        url: "https://example.com/pr/2",
        title: "Different PR",
        state: PrState.closed,
        mergeableStatus: PrMergeableStatus.unknown,
        reviewDecision: PrReviewDecision.approved,
        checkStatus: PrCheckStatus.failure,
      );

      expect(pr1, pr2);
      expect(pr1, isNot(pr3));
    });
  });
}
