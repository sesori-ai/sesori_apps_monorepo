import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("SessionArchivedRejection", () {
    test("round-trips through JSON", () {
      const rejection = SessionArchivedRejection(
        sessionId: "ses-1",
        reason: SessionArchivedReason.archivedReadOnly,
      );

      expect(rejection.toJson(), {"sessionId": "ses-1", "reason": "archived_read_only"});
      expect(SessionArchivedRejection.fromJson(rejection.toJson()), rejection);
    });

    test("does not decode as SessionCleanupRejection", () {
      // Published clients parse 409 bodies from archive/delete as a cleanup
      // rejection. The archived body must fail that parse so no bogus
      // cleanup/force dialog is shown; they fall back to a generic error.
      const rejection = SessionArchivedRejection(
        sessionId: "ses-1",
        reason: SessionArchivedReason.archivedReadOnly,
      );

      expect(
        () => SessionCleanupRejection.fromJson(rejection.toJson()),
        throwsA(anything),
      );
    });
  });
}
