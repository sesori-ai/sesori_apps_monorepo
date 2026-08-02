import "dart:async";

import "package:sesori_bridge/src/services/project_view_tracker.dart";
import "package:test/test.dart";

void main() {
  group("ProjectViewTracker", () {
    late ProjectViewTracker tracker;
    late List<ProjectViewChange> changes;
    late StreamSubscription<ProjectViewChange> subscription;

    setUp(() {
      tracker = ProjectViewTracker();
      changes = <ProjectViewChange>[];
      subscription = tracker.changes.listen(changes.add);
    });

    tearDown(() async {
      await subscription.cancel();
      await tracker.dispose();
    });

    test("unions projects viewed by different connections", () {
      tracker.setViewing(connID: 1, projectId: "project-x");
      tracker.setViewing(connID: 2, projectId: "project-y");

      expect(tracker.activeProjectIds, {"project-x", "project-y"});
      expect(changes, hasLength(2));
      expect(changes[0].activeProjectIds, {"project-x"});
      expect(changes[0].newlyAddedProjectIds, {"project-x"});
      expect(changes[1].activeProjectIds, {"project-x", "project-y"});
      expect(changes[1].newlyAddedProjectIds, {"project-y"});
    });

    test("switching a connection updates both sides of the aggregate", () {
      tracker.setViewing(connID: 1, projectId: "project-x");
      changes.clear();

      tracker.setViewing(connID: 1, projectId: "project-y");

      expect(tracker.activeProjectIds, {"project-y"});
      expect(changes, hasLength(1));
      expect(changes.single.activeProjectIds, {"project-y"});
      expect(changes.single.newlyAddedProjectIds, {"project-y"});
    });

    test("duplicate viewers do not emit duplicate activation", () {
      tracker.setViewing(connID: 1, projectId: "project-x");
      changes.clear();

      tracker.setViewing(connID: 2, projectId: "project-x");
      tracker.setViewing(connID: 2, projectId: "project-x");
      tracker.releaseConnection(connID: 1);

      expect(tracker.activeProjectIds, {"project-x"});
      expect(changes, isEmpty);

      tracker.releaseConnection(connID: 2);
      expect(changes.single.activeProjectIds, isEmpty);
      expect(changes.single.newlyAddedProjectIds, isEmpty);
    });

    test("releaseConnection removes only that connection claim", () {
      tracker.setViewing(connID: 1, projectId: "project-x");
      tracker.setViewing(connID: 2, projectId: "project-y");
      changes.clear();

      tracker.releaseConnection(connID: 1);

      expect(tracker.activeProjectIds, {"project-y"});
      expect(changes.single.activeProjectIds, {"project-y"});
      expect(changes.single.newlyAddedProjectIds, isEmpty);
    });

    test("clearAll releases every claim with one aggregate change", () {
      tracker.setViewing(connID: 1, projectId: "project-x");
      tracker.setViewing(connID: 2, projectId: "project-y");
      changes.clear();

      tracker.clearAll();
      tracker.clearAll();

      expect(tracker.activeProjectIds, isEmpty);
      expect(changes, hasLength(1));
      expect(changes.single.activeProjectIds, isEmpty);
      expect(changes.single.newlyAddedProjectIds, isEmpty);
    });

    test("a late release after clearAll cannot clear a reasserted claim", () {
      tracker.setViewing(connID: 1, projectId: "project-x");
      tracker.clearAll();
      tracker.setViewing(connID: 2, projectId: "project-x");
      changes.clear();

      tracker.releaseConnection(connID: 1);

      expect(tracker.activeProjectIds, {"project-x"});
      expect(changes, isEmpty);
    });

    test("normalizes null and empty declarations to no claim", () {
      tracker.setViewing(connID: 1, projectId: "project-x");
      tracker.setViewing(connID: 1, projectId: "");
      tracker.setViewing(connID: 1, projectId: null);

      expect(tracker.activeProjectIds, isEmpty);
      expect(changes, hasLength(2));
    });

    test("getters and emitted changes are immutable snapshots", () {
      tracker.setViewing(connID: 1, projectId: "project-x");
      final activeSnapshot = tracker.activeProjectIds;
      final changeSnapshot = changes.single;

      expect(() => activeSnapshot.add("mutation"), throwsUnsupportedError);
      expect(changeSnapshot.activeProjectIds.clear, throwsUnsupportedError);
      expect(() => changeSnapshot.newlyAddedProjectIds.add("mutation"), throwsUnsupportedError);

      tracker.setViewing(connID: 2, projectId: "project-y");
      expect(activeSnapshot, {"project-x"});
      expect(changeSnapshot.activeProjectIds, {"project-x"});
      expect(changeSnapshot.newlyAddedProjectIds, {"project-x"});
    });

    test("does not mutate or emit after disposal", () async {
      tracker.setViewing(connID: 1, projectId: "project-x");
      changes.clear();

      await tracker.dispose();
      tracker.setViewing(connID: 2, projectId: "project-y");
      tracker.releaseConnection(connID: 1);
      tracker.clearAll();

      expect(tracker.activeProjectIds, isEmpty);
      expect(changes, isEmpty);
    });
  });
}
