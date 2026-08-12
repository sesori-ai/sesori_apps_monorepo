import "dart:convert";
import "dart:typed_data";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_attachment.dart";
import "package:sesori_dart_core/src/foundation/models/session_options/session_options_request_mode.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockRelayHttpApiClient extends Mock implements RelayHttpApiClient;

void main() {
  late MockRelayHttpApiClient client;
  late SessionApi api;

  setUp(() {
    client = MockRelayHttpApiClient();
    api = SessionApi(client: client);
  });

  group("SessionApi", () {
    const options = SessionOptionsResponse(
      agents: Agents(agents: <AgentInfo>[]),
      providers: ProviderListResponse(items: <ProviderInfo>[], connectedOnly: false),
      commands: CommandListResponse(items: <CommandInfo>[]),
    );

    test("loadSessionOptions omits the query for dynamic loading", () async {
      when(
        () => client.post<SessionOptionsResponse>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
          queryParameters: any(named: "queryParameters"),
        ),
      ).thenAnswer((invocation) async {
        final parser = invocation.namedArguments[#fromJson]! as SessionOptionsResponse Function(Map<String, dynamic>);
        return ApiResponse.success(parser(options.toJson()));
      });

      final response = await api.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: SessionOptionsRequestMode.dynamic,
      );

      expect((response as SuccessResponse<SessionOptionsResponse>).data, options);
      verify(
        () => client.post<SessionOptionsResponse>(
          "/session/options",
          fromJson: any(named: "fromJson"),
          body: const PluginProjectIdRequest(projectId: "project-1", pluginId: "plugin-1"),
          queryParameters: null,
        ),
      ).called(1);
    });

    test("loadSessionOptions sends refresh=true only for an explicit refresh", () async {
      when(
        () => client.post<SessionOptionsResponse>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
          queryParameters: any(named: "queryParameters"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(options));

      await api.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: SessionOptionsRequestMode.forceRefresh,
      );

      verify(
        () => client.post<SessionOptionsResponse>(
          "/session/options",
          fromJson: any(named: "fromJson"),
          body: const PluginProjectIdRequest(projectId: "project-1", pluginId: "plugin-1"),
          queryParameters: const {"refresh": "true"},
        ),
      ).called(1);
    });

    test("loadSessionOptions sends refresh=false for cache-only loading", () async {
      when(
        () => client.post<SessionOptionsResponse>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
          queryParameters: any(named: "queryParameters"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(options));

      await api.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: SessionOptionsRequestMode.cacheOnly,
      );

      verify(
        () => client.post<SessionOptionsResponse>(
          "/session/options",
          fromJson: any(named: "fromJson"),
          body: const PluginProjectIdRequest(projectId: "project-1", pluginId: "plugin-1"),
          queryParameters: const {"refresh": "false"},
        ),
      ).called(1);
    });

    test("createSessionWithMessage builds a request body with null variant when omitted", () async {
      const session = Session(
        branchName: null,
        id: "session-1",
        pluginId: "plugin-1",
        projectID: "project-1",
        directory: "/tmp/project-1",
        parentID: null,
        title: "Session",
        time: SessionTime(created: 1, updated: 1, archived: null),
        pullRequest: null,
        promptDefaults: null,
      );

      when(
        () => client.post<Session>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(session));

      await api.createSessionWithMessage(
        attachments: const [],
        projectId: "project-1",
        pluginId: "plugin-1",
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
      expect(request.pluginId, "plugin-1");
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
        attachments: const [],
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

    test("sendMessage appends attachments as inline file_data parts after the text part", () async {
      when(
        () => client.post<void>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));

      final attachment = ComposerAttachment(
        mime: "image/png",
        bytes: Uint8List.fromList(const [1, 2, 3]),
        filename: "screenshot.png",
      );
      await api.sendMessage(
        sessionId: "session-1",
        text: "look at this",
        attachments: [attachment],
        agent: null,
        model: null,
        variant: null,
        command: null,
      );

      final verification = verify(
        () => client.post<void>(
          "/session/prompt_async",
          fromJson: any(named: "fromJson"),
          body: captureAny(named: "body"),
        ),
      )..called(1);
      final request = verification.captured.single as SendPromptRequest;
      expect(request.parts, [
        const PromptPart.text(text: "look at this"),
        PromptPart.fileData(
          mime: "image/png",
          base64: base64Encode(const [1, 2, 3]),
          filename: "screenshot.png",
        ),
      ]);
    });

    test("an attachment-only prompt omits the empty text part", () async {
      when(
        () => client.post<void>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));

      await api.sendMessage(
        sessionId: "session-1",
        text: "",
        attachments: [
          ComposerAttachment(mime: "image/jpeg", bytes: Uint8List.fromList(const [7]), filename: null),
        ],
        agent: null,
        model: null,
        variant: null,
        command: null,
      );

      final verification = verify(
        () => client.post<void>(
          "/session/prompt_async",
          fromJson: any(named: "fromJson"),
          body: captureAny(named: "body"),
        ),
      )..called(1);
      final request = verification.captured.single as SendPromptRequest;
      expect(request.parts, [
        PromptPart.fileData(mime: "image/jpeg", base64: base64Encode(const [7]), filename: null),
      ]);
    });

    test("listCommands posts the project request body", () async {
      when(
        () => client.post<CommandListResponse>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])));

      await api.listCommands(projectId: "project-1", pluginId: "plugin-1");

      verify(
        () => client.post<CommandListResponse>(
          "/command",
          fromJson: any(named: "fromJson"),
          body: const PluginProjectIdRequest(projectId: "project-1", pluginId: "plugin-1"),
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
