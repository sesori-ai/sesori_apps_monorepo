import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/services/models/session_activity_info.dart";
import "package:sesori_dart_core/src/services/project_list_service.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockProjectRepository() extends Mock implements ProjectRepository;

void main() {
  test("running projects use activity while awaiting-only and inactive projects keep timestamp order", () {
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
        "running-z": {"z": SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: 10, updatedAt: null)},
        "waiting-a": {"waiting": SessionActivityInfo(awaitingInput: true, lastUserActivityAt: 30, updatedAt: null)},
        "running-a": {"a": SessionActivityInfo(backgroundTaskCount: 1, lastUserActivityAt: 20, updatedAt: null)},
      },
      listStateByProjectId: const {},
    );

    expect(
      result.map((project) => project.id),
      ["running-a", "running-z", "waiting-a", "inactive-b"],
    );
  });

  test("live markers override summary activity and use the latest running root", () {
    final service = ProjectListService(
      repository: _MockProjectRepository(),
      activityCalculator: const SessionActivityCalculator(),
    );

    final result = service.orderProjects(
      projects: [
        _project(id: "project-a", name: "A", updatedAt: 2),
        _project(id: "project-b", name: "B", updatedAt: 1),
      ],
      activityByProjectId: const {
        "project-a": {
          "a1": SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: 70, updatedAt: null),
          "a2": SessionActivityInfo(isRetrying: true, lastUserActivityAt: 20, updatedAt: null),
        },
        "project-b": {"b": SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: 80, updatedAt: null)},
      },
      listStateByProjectId: const {
        "project-a": {"a2": (unseen: false, lastUserActivityAt: 90)},
      },
    );

    expect(result.map((project) => project.id), ["project-a", "project-b"]);
  });

  test("a fresh summary marker overrides a stale cached marker after reconnect", () {
    final service = ProjectListService(
      repository: _MockProjectRepository(),
      activityCalculator: const SessionActivityCalculator(),
    );

    final result = service.orderProjects(
      projects: [
        _project(id: "project-a", name: "A", updatedAt: 2),
        _project(id: "project-b", name: "B", updatedAt: 1),
      ],
      activityByProjectId: const {
        "project-a": {"a": SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: 100, updatedAt: 1)},
        "project-b": {"b": SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: 90, updatedAt: 200)},
      },
      listStateByProjectId: const {
        "project-a": {"a": (unseen: false, lastUserActivityAt: 10)},
      },
    );

    expect(result.map((project) => project.id), ["project-a", "project-b"]);
  });

  test("a live marker beats a markerless root's newer updated time", () {
    final service = ProjectListService(
      repository: _MockProjectRepository(),
      activityCalculator: const SessionActivityCalculator(),
    );

    final result = service.orderProjects(
      projects: [
        _project(id: "project-a", name: "A", updatedAt: 2),
        _project(id: "project-b", name: "B", updatedAt: 1),
      ],
      activityByProjectId: const {
        "project-a": {"a": SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: 100)},
        "project-b": {"b": SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: 75, updatedAt: 1)},
      },
      listStateByProjectId: const {
        "project-a": {"a": (unseen: false, lastUserActivityAt: 50)},
      },
    );

    expect(result.map((project) => project.id), ["project-b", "project-a"]);
  });

  test("old-bridge running projects fall back to project updated time and stable IDs", () {
    final service = ProjectListService(
      repository: _MockProjectRepository(),
      activityCalculator: const SessionActivityCalculator(),
    );

    final result = service.orderProjects(
      projects: [
        _project(id: "older", name: "Alpha", updatedAt: 1),
        _project(id: "newer-b", name: "Zulu", updatedAt: 2),
        _project(id: "newer-a", name: "Beta", updatedAt: 2),
      ],
      activityByProjectId: const {
        "older": {"older-root": SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null)},
        "newer-b": {"newer-b-root": SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null)},
        "newer-a": {"newer-a-root": SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null)},
      },
      listStateByProjectId: const {},
    );

    expect(result.map((project) => project.id), ["newer-a", "newer-b", "older"]);
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
