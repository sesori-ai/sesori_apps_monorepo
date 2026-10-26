import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/view_declaration_api.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:test/test.dart";

class _MockConnectionService() extends Mock implements ConnectionService;

void main() {
  test("forwards session declarations to the connection seam", () async {
    final connectionService = _MockConnectionService();
    when(() => connectionService.sendSessionView(sessionId: any(named: "sessionId"))).thenAnswer((_) async {});
    final api = ViewDeclarationApi(connectionService: connectionService);

    await api.sendSessionView(sessionId: "session-1");
    await api.sendSessionView(sessionId: null);

    verifyInOrder([
      () => connectionService.sendSessionView(sessionId: "session-1"),
      () => connectionService.sendSessionView(sessionId: null),
    ]);
  });
}
