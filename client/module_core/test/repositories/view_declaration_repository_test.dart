import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/view_declaration_api.dart";
import "package:sesori_dart_core/src/repositories/view_declaration_repository.dart";
import "package:test/test.dart";

class _MockViewDeclarationApi() extends Mock implements ViewDeclarationApi;

void main() {
  test("preserves nullable session and project declarations", () async {
    final api = _MockViewDeclarationApi();
    when(() => api.sendSessionView(sessionId: any(named: "sessionId"))).thenAnswer((_) async {});
    when(() => api.sendProjectView(projectId: any(named: "projectId"))).thenAnswer((_) async {});
    final repository = ViewDeclarationRepository(api: api);

    await repository.sendSessionView(sessionId: "session-1");
    await repository.sendSessionView(sessionId: null);
    await repository.sendProjectView(projectId: "project-1");
    await repository.sendProjectView(projectId: null);

    verifyInOrder([
      () => api.sendSessionView(sessionId: "session-1"),
      () => api.sendSessionView(sessionId: null),
      () => api.sendProjectView(projectId: "project-1"),
      () => api.sendProjectView(projectId: null),
    ]);
  });
}
