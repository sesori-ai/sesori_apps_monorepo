import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/view_declaration_api.dart";
import "package:sesori_dart_core/src/repositories/view_declaration_repository.dart";
import "package:test/test.dart";

class _MockViewDeclarationApi() extends Mock implements ViewDeclarationApi;

void main() {
  test("preserves nullable session declarations", () async {
    final api = _MockViewDeclarationApi();
    when(() => api.sendSessionView(sessionId: any(named: "sessionId"))).thenAnswer((_) async {});
    final repository = ViewDeclarationRepository(api: api);

    await repository.sendSessionView(sessionId: "session-1");
    await repository.sendSessionView(sessionId: null);

    verifyInOrder([
      () => api.sendSessionView(sessionId: "session-1"),
      () => api.sendSessionView(sessionId: null),
    ]);
  });
}
