import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("CreateSessionRequest", () {
    test("parses JSON without variant as null", () {
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

      expect(request.variant, isNull);
    });
  });

  group("SendPromptRequest", () {
    test("parses JSON without variant as null", () {
      final request = SendPromptRequest.fromJson({
        "sessionId": "session-123",
        "parts": const [
          {"type": "text", "text": "hello"},
        ],
        "agent": null,
        "model": null,
        "command": null,
      });

      expect(request.variant, isNull);
    });
  });
}
