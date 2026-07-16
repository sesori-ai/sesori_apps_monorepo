import "package:sesori_bridge/src/bridge/repositories/trackers/session_child_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("SessionChildTracker", () {
    test("requires a positive bound", () {
      expect(
        () => SessionChildTracker(maxPendingEntries: 0),
        throwsArgumentError,
      );
    });

    test("retains 1024 entries and evicts the globally oldest entry on overflow", () {
      final tracker = SessionChildTracker(
        maxPendingEntries: SessionChildTracker.defaultMaxPendingEntries,
      );

      for (var index = 0; index < SessionChildTracker.defaultMaxPendingEntries; index++) {
        expect(
          tracker.add(
            event: _pendingChild(
              pluginId: index.isEven ? "plugin-a" : "plugin-b",
              sessionId: "child-$index",
              parentId: "parent-${index % 3}",
            ),
          ),
          isNull,
        );
      }

      final evicted = tracker.add(
        event: _pendingChild(
          pluginId: "plugin-b",
          sessionId: "overflow",
          parentId: "parent-overflow",
        ),
      );

      expect(evicted?.session.id, "child-0");
      expect(tracker.length, SessionChildTracker.defaultMaxPendingEntries);
      expect(
        tracker.takeChildren(pluginId: "plugin-a", backendParentId: "parent-0").map((entry) => entry.session.id),
        isNot(contains("child-0")),
      );
    });

    test("drains only the requested plugin and parent while preserving sibling order", () {
      final tracker = SessionChildTracker(maxPendingEntries: 4);
      tracker.add(
        event: _pendingChild(pluginId: "a", sessionId: "a-1", parentId: "parent"),
      );
      tracker.add(
        event: _pendingChild(pluginId: "b", sessionId: "b-1", parentId: "parent"),
      );
      tracker.add(
        event: _pendingChild(pluginId: "a", sessionId: "a-2", parentId: "parent"),
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

    test("rejects root events", () {
      final tracker = SessionChildTracker(maxPendingEntries: 1);

      expect(
        () => tracker.add(
          event: _pendingChild(
            pluginId: "plugin",
            sessionId: "root",
            parentId: null,
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

PendingChildEvent _pendingChild({
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
  return PendingChildEvent(
    pluginId: pluginId,
    event: BridgeSseSessionCreated(info: session.toJson()),
    session: session,
  );
}
