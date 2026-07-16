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
        pluginId: legacyMissingPluginId,
        projectID: "proj_1",
        directory: "/tmp",
        parentID: null,
        title: null,
        time: null,
        pullRequest: null,
        promptDefaults: null,
        hasWorktree: true,
      );

      final json = session.toJson();
      expect(json["hasWorktree"], isTrue);
    });
  });

  group("Session.lastUserInteractionAt", () {
    test("defaults to null when missing from older JSON", () {
      final session = Session.fromJson({
        "id": "ses_1",
        "projectID": "proj_1",
        "directory": "/tmp",
        "parentID": null,
        "title": null,
        "time": null,
        "pullRequest": null,
        "promptDefaults": null,
      });

      expect(session.lastUserInteractionAt, isNull);
    });

    test("omits null and round-trips a populated timestamp", () {
      const empty = Session(
        id: "ses_empty",
        pluginId: legacyMissingPluginId,
        projectID: "proj_1",
        directory: "/tmp",
        parentID: null,
        title: null,
        time: null,
        pullRequest: null,
        promptDefaults: null,
      );
      const populated = Session(
        id: "ses_populated",
        pluginId: legacyMissingPluginId,
        projectID: "proj_1",
        directory: "/tmp",
        parentID: null,
        title: null,
        time: null,
        pullRequest: null,
        promptDefaults: null,
        lastUserInteractionAt: 123,
      );

      expect(empty.toJson(), isNot(contains("lastUserInteractionAt")));
      expect(Session.fromJson(populated.toJson()).lastUserInteractionAt, 123);
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
