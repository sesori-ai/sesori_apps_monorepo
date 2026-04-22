import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("SessionEffort", () {
    test("supports safeName and tryParse", () {
      expect(SessionEffort.low.safeName, "low");
      expect(SessionEffort.medium.safeName, "medium");
      expect(SessionEffort.max.safeName, "max");

      expect(SessionEffort.tryParse("low"), SessionEffort.low);
      expect(SessionEffort.tryParse("medium"), SessionEffort.medium);
      expect(SessionEffort.tryParse("max"), SessionEffort.max);
      expect(SessionEffort.tryParse("unknown"), isNull);
    });
  });

  group("CreateSessionRequest", () {
    test("parses old JSON without effort as null", () {
      final request = CreateSessionRequest.fromJson({
        "projectId": "project-123",
        "parts": const [
          {"type": "text", "text": "hello"},
        ],
        "agent": null,
        "model": null,
        "command": null,
        "dedicatedWorktree": false,
      });

      expect(request.effort, isNull);
    });
  });

  group("SendPromptRequest", () {
    test("parses old JSON without effort as null", () {
      final request = SendPromptRequest.fromJson({
        "sessionId": "session-123",
        "parts": const [
          {"type": "text", "text": "hello"},
        ],
        "agent": null,
        "model": null,
        "command": null,
      });

      expect(request.effort, isNull);
    });
  });
}
