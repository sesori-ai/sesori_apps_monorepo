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
}

Project _project({required String id, required String name, required int updatedAt}) {
  return Project(
    id: id,
    name: name,
    path: "/projects/$id",
    time: ProjectTime(created: 1, updated: updatedAt),
  );
}
