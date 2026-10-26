import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("Session without pull request fields", () {
    test("parses a v1.9.1 bridge payload that still carries them", () {
      const pullRequest = <String, Object?>{
        "number": 42,
        "url": "https://github.com/sesori-ai/sesori/pull/42",
        "title": "Headline pull request",
        "state": "OPEN",
        "mergeableStatus": "MERGEABLE",
        "reviewDecision": "APPROVED",
        "checkStatus": "SUCCESS",
      };

      final response = SessionListResponse.fromJson({
        "items": [
          {
            "id": "session-1",
            "projectID": "project-1",
            "directory": "/tmp/project-1",
            "parentID": null,
            "title": "Session",
            "time": null,
            "pullRequest": pullRequest,
            "pullRequestHistory": [pullRequest],
            "promptDefaults": null,
            "branchName": "feature/x",
          },
        ],
      });

      final session = response.items.single;
      expect(session.id, "session-1");
      expect(session.branchName, "feature/x");
    });

    test("serializes without the keys, which v1.9.1 apps read as no pull request", () {
      const session = Session(
        approvalOverride: null,
        autoContinuation: null,
        branchName: null,
        id: "session-1",
        projectID: "project-1",
        directory: "/tmp/project-1",
        parentID: null,
        title: "Session",
        time: null,
        promptDefaults: null,
        lastUserActivityAt: null,
      );

      final json = session.toJson();

      expect(json, isNot(contains("pullRequest")));
      expect(json, isNot(contains("pullRequestHistory")));
    });
  });
}
