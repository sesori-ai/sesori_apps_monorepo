import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/project_view_api.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:test/test.dart";

class _MockConnectionService extends Mock implements ConnectionService {}

void main() {
  test("ProjectViewApi forwards project and clear declarations to the connection seam", () async {
    final connectionService = _MockConnectionService();
    when(
      () => connectionService.sendProjectView(projectId: any(named: "projectId")),
    ).thenAnswer((_) async {});
    final api = ProjectViewApi(connectionService: connectionService);

    await api.sendProjectView(projectId: "project-1");
    await api.sendProjectView(projectId: null);

    verifyInOrder([
      () => connectionService.sendProjectView(projectId: "project-1"),
      () => connectionService.sendProjectView(projectId: null),
    ]);
  });
}
