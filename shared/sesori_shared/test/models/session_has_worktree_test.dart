import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("Session.hasWorktree", () {
    test("defaults to false when missing from JSON", () {
      final session = Session.fromJson({
        "id": "ses_1",
        "projectID": "proj_1",
        "directory": "/tmp",
        "parentID": null,
        "title": null,
        "time": null,
        "summary": null,
        "pullRequest": null,
      });

      expect(session.hasWorktree, isFalse);
    });

    test("deserializes as true when present", () {
      final session = Session.fromJson({
        "id": "ses_1",
        "projectID": "proj_1",
        "directory": "/tmp",
        "parentID": null,
        "title": null,
        "time": null,
        "summary": null,
        "pullRequest": null,
        "hasWorktree": true,
      });

      expect(session.hasWorktree, isTrue);
    });

    test("serializes hasWorktree to JSON", () {
      const session = Session(
        id: "ses_1",
        projectID: "proj_1",
        directory: "/tmp",
        parentID: null,
        title: null,
        time: null,
        summary: null,
        pullRequest: null,
        hasWorktree: true,
      );

      final json = session.toJson();
      expect(json["hasWorktree"], isTrue);
    });
  });

  group("CleanupIssue.sharedWorktree", () {
    test("deserializes from JSON", () {
      final issue = CleanupIssue.fromJson({"type": "shared_worktree"});
      expect(issue, isA<CleanupIssueSharedWorktree>());
    });

    test("serializes to JSON", () {
      const issue = CleanupIssue.sharedWorktree();
      final json = issue.toJson();
      expect(json["type"], "shared_worktree");
    });
  });
}
