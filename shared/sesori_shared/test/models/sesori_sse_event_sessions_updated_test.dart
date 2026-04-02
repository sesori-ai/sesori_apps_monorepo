import "package:test/test.dart";
import "package:sesori_shared/sesori_shared.dart";

void main() {
  group("SesoriSseEvent.sessionsUpdated", () {
    test("creates instance with projectID", () {
      const event = SesoriSseEvent.sessionsUpdated(
        projectID: "proj-123",
      );

      expect(event, isA<SesoriSessionsUpdated>());
      expect((event as SesoriSessionsUpdated).projectID, "proj-123");
    });

    test("serializes to JSON correctly", () {
      const event = SesoriSseEvent.sessionsUpdated(
        projectID: "proj-456",
      );

      final json = event.toJson();

      expect(json["type"], "sessions.updated");
      expect(json["projectID"], "proj-456");
    });

    test("deserializes from JSON correctly", () {
      final json = {
        "type": "sessions.updated",
        "projectID": "proj-789",
      };

      final event = SesoriSseEvent.fromJson(json);

      expect(event, isA<SesoriSessionsUpdated>());
      expect((event as SesoriSessionsUpdated).projectID, "proj-789");
    });

    test("supports equality comparison", () {
      const event1 = SesoriSseEvent.sessionsUpdated(projectID: "proj-1");
      const event2 = SesoriSseEvent.sessionsUpdated(projectID: "proj-1");
      const event3 = SesoriSseEvent.sessionsUpdated(projectID: "proj-2");

      expect(event1, event2);
      expect(event1, isNot(event3));
    });

    test("implements SesoriSessionEvent marker", () {
      const event = SesoriSseEvent.sessionsUpdated(projectID: "proj-test");

      expect(event, isA<SesoriSessionEvent>());
    });
  });
}
