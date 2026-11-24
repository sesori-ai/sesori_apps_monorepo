import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  Map<String, dynamic> sessionJson({required Map<String, dynamic> extra}) => {
    "id": "ses_1",
    "projectID": "proj_1",
    "directory": "/tmp",
    "parentID": null,
    "title": null,
    "time": null,
    ...extra,
  };

  test("an older bridge's session has no wake-ups and reports no arming", () {
    final session = Session.fromJson(sessionJson(extra: const {}));

    expect(session.wakeUps, isEmpty);
    expect(session.arming, const SessionArming.unreported());
  });

  test("wake-ups and arming round trip", () {
    final session = Session.fromJson(
      sessionJson(
        extra: {
          "wakeUps": [
            const SessionWakeUp(
              id: "wakeup-1",
              nextDueAt: 1000,
              label: "Check CI",
              repeats: true,
              runsCommand: false,
            ).toJson(),
          ],
          "arming": const SessionArming.armed(name: "Check CI", nextAt: 1000).toJson(),
        },
      ),
    );

    expect(session.wakeUps.single.label, "Check CI");
    expect(session.arming, const SessionArming.armed(name: "Check CI", nextAt: 1000));
    expect(Session.fromJson(session.toJson()), session);
    expect(
      Session.fromJson(session.copyWith(arming: const SessionArming.notArmed()).toJson()).arming,
      isA<SessionArmingNotArmed>(),
    );
  });

  test("an arming kind from a newer bridge reads as unreported", () {
    final session = Session.fromJson(
      sessionJson(
        extra: const {
          "arming": {"kind": "later"},
        },
      ),
    );

    expect(session.arming, const SessionArming.unreported());
  });

  test("CancelSessionWakeUpRequest round trips", () {
    const request = CancelSessionWakeUpRequest(sessionId: "ses_1", wakeUpId: "wakeup-1");

    expect(request.toJson(), {"sessionId": "ses_1", "wakeUpId": "wakeup-1"});
    expect(CancelSessionWakeUpRequest.fromJson(request.toJson()), request);
  });
}
