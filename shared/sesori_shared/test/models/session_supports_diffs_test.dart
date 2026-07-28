import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("Session.supportsSessionDiffs", () {
    test("defaults to the prior visible-button behavior when missing from JSON", () {
      final session = Session.fromJson({
        "id": "ses_1",
        "projectID": "proj_1",
        "directory": "/tmp",
        "parentID": null,
        "title": null,
        "time": null,
        "pullRequest": null,
      });

      expect(session.supportsSessionDiffs, isTrue);
    });

    test("deserializes false when the bridge cannot compute diffs", () {
      final session = Session.fromJson({
        "id": "ses_1",
        "projectID": "proj_1",
        "directory": "/tmp",
        "parentID": null,
        "title": null,
        "time": null,
        "pullRequest": null,
        "supportsSessionDiffs": false,
      });

      expect(session.supportsSessionDiffs, isFalse);
    });
  });
}
