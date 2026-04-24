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
    test("createSessionWithMessage builds a request body with null variant when omitted", () async {
      const session = Session(
        id: "session-1",
        projectID: "project-1",
        directory: "/tmp/project-1",
        parentID: null,
        title: "Session",
        summary: null,
        time: SessionTime(created: 1, updated: 1, archived: null),
        pullRequest: null,
      );

      when(
        () => client.post<Session>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(session));

      await api.createSessionWithMessage(
        projectId: "project-1",
        text: "hello",
        agent: "build",
        model: const PromptModel(providerID: "openai", modelID: "gpt-5.4"),
        variant: null,
        command: "review",
        dedicatedWorktree: true,
      );

      final verification = verify(
        () => client.post<Session>(
          "/session/create",
          fromJson: any(named: "fromJson"),
          body: captureAny(named: "body"),
        ),
      )..called(1);
      final request = verification.captured.single as CreateSessionRequest;
      expect(request.variant, isNull);
    });

    test("sendMessage builds a request body with null variant when omitted", () async {
      when(
        () => client.post<void>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));

      await api.sendMessage(
        sessionId: "session-1",
        text: "hello",
        agent: "build",
        model: const PromptModel(providerID: "openai", modelID: "gpt-5.4"),
        variant: null,
        command: "review",
      );

      final verification = verify(
        () => client.post<void>(
          "/session/prompt_async",
          fromJson: any(named: "fromJson"),
          body: captureAny(named: "body"),
        ),
      )..called(1);
      final request = verification.captured.single as SendPromptRequest;
      expect(request.variant, isNull);
    });

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
