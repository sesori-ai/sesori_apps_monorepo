import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
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

  test("session-attributed toast exposes its sessionId", () {
    final event = SseEvent(
      data: const SesoriSseEvent.tuiToastShow(
        sessionID: "session-123",
        title: "Pi",
        message: "Done",
        variant: "success",
      ),
    );

    expect(event.sessionId, "session-123");
    expect(event.data, isA<SesoriSessionEvent>());
  });

  test("unattributed toast remains outside every filtered session stream", () {
    final event = SseEvent(
      data: const SesoriSseEvent.tuiToastShow(
        sessionID: null,
        title: "Notice",
        message: null,
        variant: "info",
      ),
    );

    expect(event.sessionId, isNull);
    expect(event.data, isA<SesoriSessionEvent>());
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

  test("sessionOptionsUpdated is a global plugin event", () {
    final event = SseEvent(
      data: const SesoriSseEvent.sessionOptionsUpdated(pluginId: "cursor", projectId: null),
    );

    expect(event.sessionId, isNull);
    expect(event.data, isNot(isA<SesoriSessionEvent>()));
  });

  test("pluginAuthenticationProgress is a global plugin event", () {
    final event = SseEvent(
      data: const SesoriSseEvent.pluginAuthenticationProgress(
        pluginId: "codex",
        progress: PluginAuthenticationProgress.completed(),
      ),
    );

    expect(event.sessionId, isNull);
    expect(event.data, isNot(isA<SesoriSessionEvent>()));
  });
}
