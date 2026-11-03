import "package:sesori_dart_core/testing.dart";
import "package:test/test.dart";

void main() {
  test("FakeSessionUnseenTracker keeps session updates newer than a seed", () async {
    final tracker = FakeSessionUnseenTracker();
    addTearDown(tracker.onDispose);
    final beforeLocalUpdate = tracker.tick;

    tracker.applyLocalSessionUnseen(projectId: "project-1", sessionId: "session-1", unseen: true);
    tracker.seedSessions(
      projectId: "project-1",
      stateBySessionId: const {"session-1": (unseen: false, lastUserActivityAt: null)},
      sinceTick: beforeLocalUpdate,
    );

    expect(tracker.currentSessionUnseen["project-1"]?["session-1"]?.unseen, isTrue);
  });
}
