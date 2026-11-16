import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const base = <String, Object?>{
    "id": "permission-1",
    "sessionID": "session-1",
    "tool": "Write",
    "description": "Write a file",
  };

  test("pending permission defaults omitted always capability to true", () {
    expect(PendingPermission.fromJson(base).allowAlways, isTrue);
  });

  test("pending permission preserves an explicit false always capability", () {
    expect(PendingPermission.fromJson({...base, "allowAlways": false}).allowAlways, isFalse);
  });

  test("permission SSE defaults omitted always capability to true", () {
    final event = SesoriSseEvent.fromJson({
      "type": "permission.asked",
      "requestID": "permission-1",
      "sessionID": "session-1",
      "tool": "Write",
      "description": "Write a file",
    });

    expect((event as SesoriPermissionAsked).allowAlways, isTrue);
  });

  test("permission SSE preserves an explicit false always capability", () {
    final event = SesoriSseEvent.fromJson({
      "type": "permission.asked",
      "requestID": "permission-1",
      "sessionID": "session-1",
      "tool": "Write",
      "description": "Write a file",
      "allowAlways": false,
    });

    expect((event as SesoriPermissionAsked).allowAlways, isFalse);
  });

  test("a permissions response from an older bridge reads as not auto-accepting edits", () {
    expect(PendingPermissionResponse.fromJson(const {"data": <Object?>[]}).editsAutoAccepted, isFalse);
    expect(
      PendingPermissionResponse.fromJson(const {"data": <Object?>[], "editsAutoAccepted": true}).editsAutoAccepted,
      isTrue,
    );
  });

  test("the edits auto-accepted event round-trips as a session event", () {
    const event = SesoriSseEvent.sessionEditsAutoAccepted(sessionID: "session-1", editsAutoAccepted: true);
    final json = event.toJson();

    expect(json["type"], "session.edits-auto-accepted");
    expect(SesoriSseEvent.fromJson(json), isA<SesoriSessionEvent>().having((e) => e, "event", event));
  });
}
