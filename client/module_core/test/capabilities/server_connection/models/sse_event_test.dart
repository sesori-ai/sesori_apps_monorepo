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

  test("catalogImportProgress is a global non-session event", () {
    final event = SseEvent(
      data: const SesoriSseEvent.catalogImportProgress(
        progress: CatalogImportProgress.enumerating(
          pluginId: "codex",
          projectsSeen: 2,
          sessionsSeen: 5,
        ),
      ),
    );

    expect(event.sessionId, isNull);
    expect(event.data, isNot(isA<SesoriSessionEvent>()));
  });
}
