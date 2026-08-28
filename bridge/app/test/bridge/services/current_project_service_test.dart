import "package:sesori_bridge/src/repositories/project_repository.dart";
import "package:sesori_bridge/src/services/current_project_service.dart";
import "package:sesori_bridge/src/services/project_glossary_scope_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  late _FakeProjectRepository repository;
  late _FakeProjectGlossaryScopeService scopeService;
  late CurrentProjectService service;

  setUp(() {
    repository = _FakeProjectRepository();
    scopeService = _FakeProjectGlossaryScopeService(
      scope: ProjectGlossaryScope.repository(
        projectKey: ProjectGlossaryKey.parse(value: "prj_v1_${List.filled(43, "a").join()}"),
      ),
    );
    service = CurrentProjectService(
      projectRepository: repository,
      projectGlossaryScopeService: scopeService,
    );
    addTearDown(service.dispose);
  });

  test("publishes the authoritative id after a successful load", () async {
    final loadedProjectId = service.loadedProjectIds.first;

    final project = await service.getCurrentProject(projectId: "requested-id");

    expect(project.id, "authoritative-id");
    expect(project.voiceGlossaryKey, scopeService.scope!.projectKey);
    expect(scopeService.projectPaths, ["/workspace/project"]);
    expect(await loadedProjectId, "authoritative-id");
  });

  test("keeps the project usable when glossary scope resolution fails", () async {
    final loadedProjectId = service.loadedProjectIds.first;
    scopeService.error = StateError("git unavailable");

    final project = await service.getCurrentProject(projectId: "requested-id");

    expect(project.voiceGlossaryKey, isNull);
    expect(await loadedProjectId, "authoritative-id");
  });

  test("does not publish a failed load", () async {
    final loadedProjectIds = <String>[];
    final subscription = service.loadedProjectIds.listen(loadedProjectIds.add);
    addTearDown(subscription.cancel);
    repository.error = StateError("missing project");

    await expectLater(
      service.getCurrentProject(projectId: "missing-id"),
      throwsA(same(repository.error)),
    );

    expect(loadedProjectIds, isEmpty);
  });
}

final class _FakeProjectGlossaryScopeService({required var ProjectGlossaryScope? scope})
    implements ProjectGlossaryScopeService {
  Object? error;
  final List<String> projectPaths = [];

  @override
  Future<ProjectGlossaryScope?> resolve({required String projectPath}) async {
    projectPaths.add(projectPath);
    if (error case final error?) throw error;
    return scope;
  }
}

final class _FakeProjectRepository() implements ProjectRepository {
  Object? error;

  @override
  Future<Project> getProject({required String projectId}) async {
    if (error case final error?) throw error;
    return const Project(
      id: "authoritative-id",
      name: "Project",
      path: "/workspace/project",
      time: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
