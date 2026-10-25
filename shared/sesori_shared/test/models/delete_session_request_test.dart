import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("DeleteSessionRequest", () {
    test("reads an older app's omitted deleteSessionFolder as keeping the folder", () {
      final request = DeleteSessionRequest.fromJson({
        "sessionId": "session-1",
        "deleteWorktree": true,
        "deleteBranch": false,
        "force": false,
      });

      expect(request.deleteSessionFolder, isFalse);
    });

    test("JSON roundtrip carries deleteSessionFolder", () {
      const request = DeleteSessionRequest(
        sessionId: "session-1",
        deleteWorktree: false,
        deleteBranch: false,
        force: false,
        deleteSessionFolder: true,
      );

      final json = request.toJson();

      expect(json, containsPair("deleteSessionFolder", true));
      expect(DeleteSessionRequest.fromJson(json), request);
    });
  });
}
