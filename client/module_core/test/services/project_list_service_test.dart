import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/services/project_list_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late ProjectListService service;

  setUp(() {
    service = ProjectListService(repository: _MockProjectRepository());
  });

  test("ordered summaries define the active prefix and preserve the legacy tail", () {
    final result = service.orderProjects(
      projects: [
        _project(id: "inactive-z", name: "Zulu"),
        _project(id: "active-a", name: "Alpha"),
        _project(id: "inactive-a", name: "Alpha"),
        _project(id: "active-z", name: "Zulu"),
      ],
      activeProjectIds: const ["active-z", "active-a"],
      userInteractionOrdered: true,
    );

    expect(result.map((project) => project.id), ["active-z", "active-a", "inactive-a", "inactive-z"]);
  });

  test("older summaries retain the complete legacy project order", () {
    final result = service.orderProjects(
      projects: [
        _project(id: "z", name: "Zulu"),
        _project(id: "a", name: "Alpha"),
      ],
      activeProjectIds: const ["z"],
      userInteractionOrdered: false,
    );

    expect(result.map((project) => project.id), ["a", "z"]);
  });

  test("unknown active IDs do not disturb known projects", () {
    final result = service.orderProjects(
      projects: [
        _project(id: "b", name: "Beta"),
        _project(id: "a", name: "Alpha"),
      ],
      activeProjectIds: const ["missing", "b"],
      userInteractionOrdered: true,
    );

    expect(result.map((project) => project.id), ["b", "a"]);
  });
}

Project _project({required String id, required String name}) {
  return Project(id: id, name: name, path: id, time: null);
}
