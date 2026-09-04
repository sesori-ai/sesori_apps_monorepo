import "dart:async";

import "package:sesori_bridge/src/listeners/current_project_glossary_listener.dart";
import "package:sesori_bridge/src/listeners/viewed_project_glossary_listener.dart";
import "package:sesori_bridge/src/services/project_glossary_population_service.dart";
import "package:sesori_bridge/src/services/project_view_tracker.dart";
import "package:test/test.dart";

void main() {
  group("CurrentProjectGlossaryListener", () {
    late StreamController<String> source;
    late _FakeProjectGlossaryPopulationService service;
    late CurrentProjectGlossaryListener listener;

    setUp(() {
      source = StreamController<String>.broadcast(sync: true);
      service = _FakeProjectGlossaryPopulationService();
      listener = CurrentProjectGlossaryListener(source: source.stream, service: service)..start();
    });

    tearDown(() async {
      await listener.dispose();
      await source.close();
    });

    test("delegates each successful current-project load", () async {
      source
        ..add("project-1")
        ..add("project-2");

      await listener.dispose();

      expect(service.projectIds, ["project-1", "project-2"]);
    });

    test("contains population failures and continues listening", () async {
      service.failProjectIds.add("project-1");
      source
        ..add("project-1")
        ..add("project-2");

      await listener.dispose();

      expect(service.projectIds, ["project-1", "project-2"]);
    });
  });

  group("ViewedProjectGlossaryListener", () {
    late ProjectViewTracker tracker;
    late _FakeProjectGlossaryPopulationService service;
    late ViewedProjectGlossaryListener listener;

    setUp(() {
      tracker = ProjectViewTracker();
      service = _FakeProjectGlossaryPopulationService();
    });

    tearDown(() async {
      await listener.dispose();
      await tracker.dispose();
    });

    test("populates active and newly viewed projects without viewer-count duplicates", () async {
      tracker.setViewing(connID: 1, projectId: "project-1");
      listener = ViewedProjectGlossaryListener(tracker: tracker, service: service)..start();

      tracker.setViewing(connID: 2, projectId: "project-1");
      tracker.setViewing(connID: 1, projectId: "project-2");
      tracker.releaseConnection(connID: 2);
      tracker.setViewing(connID: 2, projectId: "project-1");
      await listener.dispose();

      expect(service.projectIds, ["project-1", "project-2", "project-1"]);
    });

    test("does not populate projects after disposal", () async {
      listener = ViewedProjectGlossaryListener(tracker: tracker, service: service)..start();
      await listener.dispose();

      tracker.setViewing(connID: 1, projectId: "project-1");

      expect(service.projectIds, isEmpty);
    });
  });
}

final class _FakeProjectGlossaryPopulationService() implements ProjectGlossaryPopulationService {
  final List<String> projectIds = [];
  final Set<String> failProjectIds = {};

  @override
  Future<void> populate({required String projectId}) async {
    projectIds.add(projectId);
    if (failProjectIds.contains(projectId)) {
      throw StateError("population failed");
    }
  }

  @override
  void beginShutdown() {}

  @override
  Future<void> dispose() async {}
}
