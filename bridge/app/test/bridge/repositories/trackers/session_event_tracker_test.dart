import "package:sesori_bridge/src/bridge/repositories/trackers/session_event_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("SessionEventTracker", () {
    test("requires a positive bound", () {
      expect(
        () => SessionEventTracker(maxPendingEntriesPerPlugin: 0),
        throwsArgumentError,
      );
    });

    test("evicts only the oldest entry in the plugin whose bound overflows", () {
      final tracker = SessionEventTracker(
        maxPendingEntriesPerPlugin: SessionEventTracker.defaultMaxPendingEntries,
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
              pluginId: "plugin-a",
              sessionId: "child-$index",
              parentId: "parent-${index % 3}",
            ),
          ),
          isNull,
        );
      }
      tracker.addRoot(
        event: _pending(pluginId: "plugin-b", sessionId: "other-root", parentId: null),
      );

      final evicted = tracker.addChild(
        event: _pending(
          pluginId: "plugin-a",
          sessionId: "overflow",
          parentId: "parent-overflow",
        ),
      );

      expect(evicted?.backendSessionId, "root");
      expect(tracker.length, SessionEventTracker.defaultMaxPendingEntries + 1);
      expect(tracker.takeRoot(pluginId: "plugin-a", backendSessionId: "root"), isNull);
      expect(
        tracker.takeRoot(pluginId: "plugin-b", backendSessionId: "other-root"),
        isNotNull,
      );
    });

    test("drains only the requested plugin and parent while preserving sibling order", () {
      final tracker = SessionEventTracker(maxPendingEntriesPerPlugin: 4);
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
      final tracker = SessionEventTracker(maxPendingEntriesPerPlugin: 2);
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

    test("drains child projections and following input in source order", () {
      final tracker = SessionEventTracker(maxPendingEntriesPerPlugin: 4);
      tracker.addRoot(
        event: _pending(pluginId: "a", sessionId: "root", parentId: null),
      );
      tracker.addChild(
        event: _pending(pluginId: "a", sessionId: "child", parentId: "root"),
      );
      tracker.addTranslation(
        event: _pendingTranslation(
          pluginId: "a",
          backendSessionId: "child",
        ),
      );

      expect(tracker.isBindingPending(pluginId: "a", backendSessionId: "child"), isTrue);
      tracker.takeRoot(pluginId: "a", backendSessionId: "root");
      final rootReady = tracker.takeReady(pluginId: "a", backendSessionId: "root");
      expect(rootReady, [isA<PendingSessionEvent>()]);

      final childReady = tracker.takeReady(pluginId: "a", backendSessionId: "child");
      expect(childReady, [isA<PendingTranslationEvent>()]);
      expect(tracker.length, 0);
    });

    test("keeps child input ahead of a later pending child update", () {
      final tracker = SessionEventTracker(maxPendingEntriesPerPlugin: 4);
      tracker.addChild(
        event: _pending(pluginId: "a", sessionId: "child", parentId: "root"),
      );
      tracker.addTranslation(
        event: _pendingTranslation(
          pluginId: "a",
          backendSessionId: "child",
        ),
      );
      tracker.addChild(
        event: _pending(
          pluginId: "a",
          sessionId: "child",
          parentId: "root",
          updated: true,
        ),
      );

      final readyBindings = {
        (pluginId: "a", backendSessionId: "root"),
      };
      final child = tracker.takeNextReady(readyBindings: readyBindings);
      expect(child, isA<PendingSessionEvent>());
      readyBindings.add((pluginId: "a", backendSessionId: "child"));
      expect(tracker.takeNextReady(readyBindings: readyBindings), isA<PendingTranslationEvent>());
      final update = tracker.takeNextReady(readyBindings: readyBindings);
      expect(update, isA<PendingTranslationEvent>());
      expect(update?.event, isA<BridgeSseSessionUpdated>());
      expect(tracker.length, 0);
    });

    test("rejects translation retention without a pending binding", () {
      final tracker = SessionEventTracker(maxPendingEntriesPerPlugin: 1);

      expect(
        () => tracker.addTranslation(
          event: _pendingTranslation(
            pluginId: "a",
            backendSessionId: "unknown",
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

PendingSessionEvent _pending({
  required String pluginId,
  required String sessionId,
  required String? parentId,
  bool updated = false,
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
    event: updated
        ? BridgeSseSessionUpdated(info: session.toJson(), titleChanged: false)
        : BridgeSseSessionCreated(info: session.toJson()),
    session: session,
    projectionUpdatedAt: 1,
  );
}

PendingTranslationEvent _pendingTranslation({
  required String pluginId,
  required String backendSessionId,
}) {
  return PendingTranslationEvent(
    pluginId: pluginId,
    event: BridgeSsePermissionAsked(
      requestID: "permission-$backendSessionId",
      sessionID: backendSessionId,
      displaySessionId: "root",
      tool: "bash",
      description: "continue",
    ),
    backendSessionId: backendSessionId,
    projectionUpdatedAt: 2,
  );
}
