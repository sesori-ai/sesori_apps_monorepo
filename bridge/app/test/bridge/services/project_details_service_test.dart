import "package:sesori_bridge/src/repositories/project_repository.dart";
import "package:sesori_bridge/src/services/project_details_service.dart";
import "package:sesori_bridge/src/services/project_glossary_population_service.dart";
import "package:sesori_bridge/src/services/project_glossary_scope_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  late _FakeProjectRepository repository;
  late _FakeProjectGlossaryScopeService scopeService;
  late _FakeProjectGlossaryPopulationService populationService;
  late ProjectDetailsService service;

  final scope = ProjectGlossaryScope.repository(
    projectKey: ProjectGlossaryKey.parse(
      value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
    ),
  );

  setUp(() {
    repository = _FakeProjectRepository();
    scopeService = _FakeProjectGlossaryScopeService();
    populationService = _FakeProjectGlossaryPopulationService();
    service = ProjectDetailsService(
      projectRepository: repository,
      projectGlossaryScopeService: scopeService,
      projectGlossaryPopulationService: populationService,
    );
  });

  test("answers with the glossary key and asks for a refresh of that glossary", () async {
    scopeService.scope = scope;

    final project = await service.getProject(projectId: "requested-id");

    expect(project.id, "authoritative-id");
    expect(project.voiceGlossaryKey, scope.projectKey);
    expect(scopeService.resolvedPaths, ["/workspace/project"]);
    expect(populationService.refreshes, [(scope: scope, projectPath: "/workspace/project")]);
    expect(repository.loads, 1);
  });

  test("a project with no glossary scope answers without a key or a refresh", () async {
    final project = await service.getProject(projectId: "requested-id");

    expect(project.voiceGlossaryKey, isNull);
    expect(populationService.refreshes, isEmpty);
  });

  test("a failed key lookup still answers with the project", () async {
    scopeService.error = StateError("git failed");

    final project = await service.getProject(projectId: "requested-id");

    expect(project.id, "authoritative-id");
    expect(project.voiceGlossaryKey, isNull);
    expect(populationService.refreshes, isEmpty);
  });

  test("a failed load resolves nothing", () async {
    repository.error = StateError("missing project");

    await expectLater(
      service.getProject(projectId: "missing-id"),
      throwsA(same(repository.error)),
    );

    expect(scopeService.resolvedPaths, isEmpty);
    expect(populationService.refreshes, isEmpty);
  });
}

final class _FakeProjectRepository() implements ProjectRepository {
  Object? error;
  int loads = 0;

  @override
  Future<Project> getProject({required String projectId}) async {
    loads++;
    if (error case final error?) throw error;
    return const Project(
      id: "authoritative-id",
      name: "Project",
      path: "/workspace/project",
      time: null,
      voiceGlossaryKey: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeProjectGlossaryScopeService() implements ProjectGlossaryScopeService {
  ProjectGlossaryScope? scope;
  Object? error;
  final List<String> resolvedPaths = [];

  @override
  Future<ProjectGlossaryScope?> resolve({required String projectPath}) async {
    resolvedPaths.add(projectPath);
    if (error case final error?) throw error;
    return scope;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeProjectGlossaryPopulationService() implements ProjectGlossaryPopulationService {
  final List<({ProjectGlossaryScope scope, String projectPath})> refreshes = [];

  @override
  Future<void> refreshIfDue({required ProjectGlossaryScope scope, required String projectPath}) async {
    refreshes.add((scope: scope, projectPath: projectPath));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
