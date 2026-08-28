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
    scopeService = _FakeProjectGlossaryScopeService();
    service = CurrentProjectService(
      projectRepository: repository,
      projectGlossaryScopeService: scopeService,
    );
    addTearDown(service.dispose);
  });

  test("publishes the authoritative id and cached glossary key after a successful load", () async {
    final glossaryKey = ProjectGlossaryKey.parse(
      value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
    );
    scopeService.cachedKey = glossaryKey;
    final loadedProjectId = service.loadedProjectIds.first;

    final project = await service.getCurrentProject(projectId: "requested-id");

    expect(project.id, "authoritative-id");
    expect(project.voiceGlossaryKey, glossaryKey);
    expect(scopeService.projectPaths, ["/workspace/project"]);
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
      voiceGlossaryKey: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeProjectGlossaryScopeService() implements ProjectGlossaryScopeService {
  ProjectGlossaryKey? cachedKey;
  final List<String> projectPaths = [];

  @override
  ProjectGlossaryKey? cachedProjectKey({required String projectPath}) {
    projectPaths.add(projectPath);
    return cachedKey;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
