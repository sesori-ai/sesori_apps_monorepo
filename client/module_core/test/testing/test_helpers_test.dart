import "package:sesori_dart_core/testing.dart";
import "package:test/test.dart";

void main() {
  test("FakeSessionUnseenTracker keeps project updates newer than a seed", () async {
    final tracker = FakeSessionUnseenTracker();
    addTearDown(tracker.onDispose);
    final beforeLocalUpdate = tracker.tick;

    tracker.emitProjectUnseen(const {"project-1": true});
    tracker.applyLocalSessionUnseen(projectId: "project-1", sessionId: "session-1", unseen: true);
    tracker.seedProjects(const {"project-1": false}, sinceTick: beforeLocalUpdate);

    expect(tracker.currentProjectUnseen["project-1"], isTrue);
  });
}
