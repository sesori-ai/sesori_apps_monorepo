import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const base = {
    "id": "ses_1",
    "projectID": "proj_1",
    "directory": "/tmp",
    "parentID": null,
    "title": null,
    "time": null,
  };

  test("a session from a bridge that sends no interruption has none", () {
    expect(Session.fromJson(base).interruption, isNull);
  });

  test("an interruption round-trips through the session JSON", () {
    final session = Session.fromJson({
      ...base,
      "interruption": {"afterMessageId": "msg_2", "unacknowledged": true},
    });

    expect(session.interruption, const SessionInterruption(afterMessageId: "msg_2", unacknowledged: true));
    expect(Session.fromJson(session.toJson()).interruption, session.interruption);
  });
}
