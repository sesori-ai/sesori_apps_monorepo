import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("a session from a bridge before pinning reads as unpinned", () {
    final session = Session.fromJson(const {
      "id": "ses_1",
      "projectID": "proj_1",
      "directory": "/tmp",
      "parentID": null,
      "title": null,
      "time": null,
    });

    expect(session.pinned, isFalse);
    expect(Session.fromJson(session.copyWith(pinned: true).toJson()).pinned, isTrue);
  });

  test("a page request from an app before pinning keeps time order", () {
    final request = SessionPageRequest.fromJson(const {
      "mode": "active",
      "filter": "all",
      "limit": 200,
    });

    expect(request.pinnedFirst, isFalse);
  });
}
