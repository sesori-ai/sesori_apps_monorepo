import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const headline = PullRequestInfo(
    number: 42,
    url: "https://github.com/sesori-ai/sesori/pull/42",
    title: "Headline pull request",
    state: PrState.open,
    mergeableStatus: PrMergeableStatus.mergeable,
    reviewDecision: PrReviewDecision.approved,
    checkStatus: PrCheckStatus.success,
  );
  const historical = PullRequestInfo(
    number: 41,
    url: "https://github.com/sesori-ai/sesori/pull/41",
    title: "Historical pull request",
    state: PrState.merged,
    mergeableStatus: PrMergeableStatus.unknown,
    reviewDecision: PrReviewDecision.approved,
    checkStatus: PrCheckStatus.success,
  );

  group("Session.pullRequestHistory", () {
    test("defaults omitted legacy history to an empty non-null list", () {
      final session = Session.fromJson({
        "id": "session-1",
        "projectID": "project-1",
        "directory": "/tmp/project-1",
        "parentID": null,
        "title": "Session",
        "time": null,
        "pullRequest": headline.toJson(),
        "promptDefaults": null,
      });

      expect(session.pullRequest, headline);
      expect(session.pullRequestHistory, isEmpty);
    });

    test("round-trips an empty history", () {
      const session = Session(
        id: "session-1",
        projectID: "project-1",
        directory: "/tmp/project-1",
        parentID: null,
        title: "Session",
        time: null,
        pullRequest: null,
        promptDefaults: null,
      );

      final json = session.toJson();

      expect(json["pullRequestHistory"], isEmpty);
      expect(Session.fromJson(json), session);
    });

    test("round-trips populated history without changing the headline", () {
      const session = Session(
        id: "session-1",
        projectID: "project-1",
        directory: "/tmp/project-1",
        parentID: null,
        title: "Session",
        time: null,
        pullRequest: headline,
        pullRequestHistory: <PullRequestInfo>[historical],
        promptDefaults: null,
      );

      final decoded = Session.fromJson(session.toJson());

      expect(decoded.pullRequest, headline);
      expect(decoded.pullRequestHistory, equals(const <PullRequestInfo>[historical]));
      expect(decoded, session);
    });
  });
}
