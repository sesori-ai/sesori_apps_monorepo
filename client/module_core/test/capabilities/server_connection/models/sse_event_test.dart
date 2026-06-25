import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("sessionPromptDefaultsChanged exposes its sessionId", () {
    final event = SseEvent(
      data: const SesoriSseEvent.sessionPromptDefaultsChanged(
        sessionID: "session-123",
        promptDefaults: SessionPromptDefaults(agent: null, model: null),
      ),
    );

    expect(event.sessionId, equals("session-123"));
  });
}
