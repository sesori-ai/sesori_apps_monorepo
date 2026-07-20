import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("Session.branchName", () {
    test("deserializes to null when missing from JSON", () {
      final session = Session.fromJson({
        "id": "ses_1",
        "projectID": "proj_1",
        "directory": "/tmp",
        "parentID": null,
        "title": null,
        "time": null,
        "pullRequest": null,
      });

      expect(session.branchName, isNull);
    });

    test("deserializes the branch when present", () {
      final session = Session.fromJson({
        "id": "ses_1",
        "projectID": "proj_1",
        "directory": "/tmp",
        "parentID": null,
        "title": null,
        "time": null,
        "pullRequest": null,
        "branchName": "sesori/add-search",
        "hasWorktree": true,
      });

      expect(session.branchName, "sesori/add-search");
    });

    test("serializes branchName to JSON", () {
      const session = Session(
        branchName: "sesori/add-search",
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
      expect(json["branchName"], "sesori/add-search");
    });
  });
}
