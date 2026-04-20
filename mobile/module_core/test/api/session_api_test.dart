import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockRelayHttpApiClient extends Mock implements RelayHttpApiClient {}

void main() {
  late MockRelayHttpApiClient client;
  late SessionApi api;

  setUp(() {
    client = MockRelayHttpApiClient();
    api = SessionApi(client: client);
  });

  group("SessionApi", () {
    test("listCommands posts the project request body", () async {
      when(
        () => client.post<CommandListResponse>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])));

      await api.listCommands(projectId: "project-1");

      verify(
        () => client.post<CommandListResponse>(
          "/command",
          fromJson: any(named: "fromJson"),
          body: const ProjectIdRequest(projectId: "project-1"),
        ),
      ).called(1);
    });

    test("getSessionDiffs posts the session id request", () async {
      when(
        () => client.post<SessionDiffsResponse>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(const SessionDiffsResponse(diffs: <FileDiff>[])));

      await api.getSessionDiffs(sessionId: "session-1");

      verify(
        () => client.post<SessionDiffsResponse>(
          "/session/diffs",
          fromJson: any(named: "fromJson"),
          body: const SessionIdRequest(sessionId: "session-1"),
        ),
      ).called(1);
    });
  });
}
