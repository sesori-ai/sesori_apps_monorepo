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

    expect(session.pinOrder, isNull);
    expect(session.pinned, isFalse);
    final pinned = Session.fromJson(session.copyWith(pinOrder: 7).toJson());
    expect(pinned.pinOrder, 7);
    expect(pinned.pinned, isTrue);
  });

  test("a page request from an app before pinning keeps time order", () {
    final request = SessionPageRequest.fromJson(const {
      "mode": "active",
      "filter": "all",
      "limit": 200,
    });

    expect(request.pinnedFirst, isFalse);
  });

  test("a pin move round-trips its top-of-group anchor", () {
    const request = MoveSessionPinRequest(sessionId: "ses_1", afterSessionId: null);

    expect(MoveSessionPinRequest.fromJson(request.toJson()), request);
  });
}
