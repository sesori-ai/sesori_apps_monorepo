import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/view_declaration_api.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:test/test.dart";

class _MockConnectionService() extends Mock implements ConnectionService;

void main() {
  test("forwards session and project declarations to the connection seam", () async {
    final connectionService = _MockConnectionService();
    when(() => connectionService.sendSessionView(sessionId: any(named: "sessionId"))).thenAnswer((_) async {});
    when(() => connectionService.sendProjectView(projectId: any(named: "projectId"))).thenAnswer((_) async {});
    final api = ViewDeclarationApi(connectionService: connectionService);

    await api.sendSessionView(sessionId: "session-1");
    await api.sendSessionView(sessionId: null);
    await api.sendProjectView(projectId: "project-1");
    await api.sendProjectView(projectId: null);

    verifyInOrder([
      () => connectionService.sendSessionView(sessionId: "session-1"),
      () => connectionService.sendSessionView(sessionId: null),
      () => connectionService.sendProjectView(projectId: "project-1"),
      () => connectionService.sendProjectView(projectId: null),
    ]);
  });
}
