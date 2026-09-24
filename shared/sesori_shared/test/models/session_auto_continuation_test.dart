import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  final legacy = <String, Object?>{"id": "session", "projectID": "/fixture", "directory": "/fixture"};

  test("older bridge omission stays unavailable and is omitted when serialized", () {
    final session = Session.fromJson(legacy);
    expect(session.autoContinuation, isNull);
    expect(session.toJson().containsKey("autoContinuation"), isFalse);
  });

  test("preference and UTC millisecond deadlines round-trip independently", () {
    const view = SessionAutoContinuationView(
      enabled: false,
      availability: AutoContinuationAvailability.conditional,
      status: SessionAutoContinuationStatus.resetKnown(resetAt: 1801000000000, continueAt: 1801000120000),
    );
    final session = Session.fromJson({...legacy, "autoContinuation": view.toJson()});
    expect(Session.fromJson(session.toJson()).autoContinuation, view);
    expect(session.autoContinuation!.enabled, isFalse);
  });

  test("future statuses and enum values degrade to explicit unknown values", () {
    final view = SessionAutoContinuationView.fromJson({
      "enabled": true,
      "availability": "future-support",
      "status": {"kind": "future-state"},
    });
    expect(view.availability, AutoContinuationAvailability.unknown);
    expect(view.status, const SessionAutoContinuationStatus.unknown());
    expect(
      SessionAutoContinuationStatus.fromJson({
        "kind": "paused",
        "resetAt": 1,
        "continueAt": 2,
        "reason": "future-reason",
      }),
      const SessionAutoContinuationStatus.paused(
        resetAt: 1,
        continueAt: 2,
        reason: AutoContinuationPauseReason.unknown,
      ),
    );
  });

  test("toggle request requires an explicit preference", () {
    const request = SetSessionAutoContinuationRequest(sessionId: "session", enabled: false);
    expect(SetSessionAutoContinuationRequest.fromJson(request.toJson()), request);
    expect(() => SetSessionAutoContinuationRequest.fromJson({"sessionId": "session"}), throwsA(isA<TypeError>()));
  });
}
