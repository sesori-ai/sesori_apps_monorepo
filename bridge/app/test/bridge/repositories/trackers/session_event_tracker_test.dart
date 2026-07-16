import "package:sesori_bridge/src/bridge/repositories/trackers/session_event_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("SessionEventTracker", () {
    test("requires a positive bound", () {
      expect(
        () => SessionEventTracker(maxPendingEntries: 0),
        throwsArgumentError,
      );
    });

    test("evicts the globally oldest root or child when the shared bound overflows", () {
      final tracker = SessionEventTracker(
        maxPendingEntries: SessionEventTracker.defaultMaxPendingEntries,
      );

      expect(
        tracker.addRoot(
          event: _pending(pluginId: "plugin-a", sessionId: "root", parentId: null),
        ),
        isNull,
      );
      for (var index = 1; index < SessionEventTracker.defaultMaxPendingEntries; index++) {
        expect(
          tracker.addChild(
            event: _pending(
              pluginId: index.isEven ? "plugin-a" : "plugin-b",
              sessionId: "child-$index",
              parentId: "parent-${index % 3}",
            ),
          ),
          isNull,
        );
      }

      final evicted = tracker.addChild(
        event: _pending(
          pluginId: "plugin-b",
          sessionId: "overflow",
          parentId: "parent-overflow",
        ),
      );

      expect(evicted?.session.id, "root");
      expect(tracker.length, SessionEventTracker.defaultMaxPendingEntries);
      expect(tracker.takeRoot(pluginId: "plugin-a", backendSessionId: "root"), isNull);
    });

    test("drains only the requested plugin and parent while preserving sibling order", () {
      final tracker = SessionEventTracker(maxPendingEntries: 4);
      tracker.addChild(
        event: _pending(pluginId: "a", sessionId: "a-1", parentId: "parent"),
      );
      tracker.addChild(
        event: _pending(pluginId: "b", sessionId: "b-1", parentId: "parent"),
      );
      tracker.addChild(
        event: _pending(pluginId: "a", sessionId: "a-2", parentId: "parent"),
      );

      expect(
        tracker.takeChildren(pluginId: "a", backendParentId: "parent").map((entry) => entry.session.id),
        ["a-1", "a-2"],
      );
      expect(tracker.length, 1);
      expect(
        tracker.takeChildren(pluginId: "b", backendParentId: "parent").map((entry) => entry.session.id),
        ["b-1"],
      );
      expect(tracker.length, 0);
    });

    test("stores pending roots separately by plugin and backend session", () {
      final tracker = SessionEventTracker(maxPendingEntries: 2);
      tracker.addRoot(
        event: _pending(pluginId: "a", sessionId: "root", parentId: null),
      );
      tracker.addRoot(
        event: _pending(pluginId: "b", sessionId: "root", parentId: null),
      );

      expect(tracker.takeRoot(pluginId: "a", backendSessionId: "root")?.pluginId, "a");
      expect(tracker.takeRoot(pluginId: "a", backendSessionId: "root"), isNull);
      expect(tracker.takeRoot(pluginId: "b", backendSessionId: "root")?.pluginId, "b");
      expect(tracker.length, 0);
    });
  });
}

PendingSessionEvent _pending({
  required String pluginId,
  required String sessionId,
  required String? parentId,
}) {
  final session = Session(
    id: sessionId,
    pluginId: pluginId,
    projectID: "project",
    directory: "/repo/$sessionId",
    parentID: parentId,
    title: null,
    time: null,
    pullRequest: null,
    promptDefaults: null,
  );
  return PendingSessionEvent(
    pluginId: pluginId,
    event: BridgeSseSessionCreated(info: session.toJson()),
    session: session,
    projectionUpdatedAt: 1,
  );
}
