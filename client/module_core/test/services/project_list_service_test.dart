import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/services/models/session_activity_info.dart";
import "package:sesori_dart_core/src/services/project_list_service.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  test("running projects form an alphabetical prefix while the tail stays timestamp ordered", () {
    final service = ProjectListService(
      repository: _MockProjectRepository(),
      activityCalculator: const SessionActivityCalculator(),
    );

    final result = service.orderProjects(
      projects: [
        _project(id: "running-z", name: "Zulu", updatedAt: 400),
        _project(id: "waiting-a", name: "Alpha", updatedAt: 300),
        _project(id: "inactive-b", name: "Beta", updatedAt: 200),
        _project(id: "running-a", name: "Alpha", updatedAt: 100),
      ],
      activityByProjectId: const {
        "running-z": {"z": SessionActivityInfo(mainAgentRunning: true)},
        "waiting-a": {"waiting": SessionActivityInfo(awaitingInput: true)},
        "running-a": {"a": SessionActivityInfo(backgroundTaskCount: 1)},
      },
    );

    expect(
      result.map((project) => project.id),
      ["running-a", "running-z", "waiting-a", "inactive-b"],
    );
  });

  test("nameless running projects sort by their displayed directory basename", () {
    final service = ProjectListService(
      repository: _MockProjectRepository(),
      activityCalculator: const SessionActivityCalculator(),
    );

    final result = service.orderProjects(
      projects: [
        _project(id: "zulu", name: null, path: "/a/Zulu", updatedAt: 2),
        _project(id: "alpha", name: null, path: r"C:\z\Alpha", updatedAt: 1),
      ],
      activityByProjectId: const {
        "zulu": {"z": SessionActivityInfo(mainAgentRunning: true)},
        "alpha": {"a": SessionActivityInfo(mainAgentRunning: true)},
      },
    );

    expect(result.map((project) => project.id), ["alpha", "zulu"]);
  });
}

Project _project({required String id, required String? name, required int updatedAt, String? path}) {
  return Project(
    id: id,
    name: name,
    path: path ?? "/projects/$id",
    time: ProjectTime(created: 1, updated: updatedAt),
  );
}
