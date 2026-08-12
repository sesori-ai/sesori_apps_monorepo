import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/project_view_api.dart";
import "package:sesori_dart_core/src/repositories/project_view_repository.dart";
import "package:test/test.dart";

class _MockProjectViewApi() extends Mock implements ProjectViewApi;

void main() {
  test("ProjectViewRepository preserves the nullable declaration", () async {
    final api = _MockProjectViewApi();
    when(() => api.sendProjectView(projectId: any(named: "projectId"))).thenAnswer((_) async {});
    final repository = ProjectViewRepository(api: api);

    await repository.sendProjectView(projectId: "project-1");
    await repository.sendProjectView(projectId: null);

    verifyInOrder([
      () => api.sendProjectView(projectId: "project-1"),
      () => api.sendProjectView(projectId: null),
    ]);
  });
}
