import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/session/session_service.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("SessionService", () {
    late MockRelayHttpApiClient mockClient;
    late SessionService sessionService;

    setUp(() {
      mockClient = MockRelayHttpApiClient();
      sessionService = SessionService(mockClient);
    });

    // -----------------------------------------------------------------------
    // agents and providers
    // -----------------------------------------------------------------------

    group("listAgents", () {
      test("success: returns List<AgentInfo> from GET /agent", () async {
        final agents = [testAgentInfo()];
        when(
          () => mockClient.get<List<AgentInfo>>(
            "/agent",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(agents));

        final result = await sessionService.listAgents();

        expect(result, isA<SuccessResponse<List<AgentInfo>>>());
        expect((result as SuccessResponse<List<AgentInfo>>).data, equals(agents));
        verify(
          () => mockClient.get<List<AgentInfo>>(
            "/agent",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });

      test("error: propagates API error from GET /agent", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.get<List<AgentInfo>>(
            "/agent",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.listAgents();

        expect(result, isA<ErrorResponse<List<AgentInfo>>>());
        expect((result as ErrorResponse<List<AgentInfo>>).error, equals(error));
        verify(
          () => mockClient.get<List<AgentInfo>>(
            "/agent",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });
    });

    group("listProviders", () {
      test("success: returns ProviderListResponse from GET /provider", () async {
        final providers = testProviderListResponse();
        when(
          () => mockClient.get<ProviderListResponse>(
            "/provider",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(providers));

        final result = await sessionService.listProviders();

        expect(result, isA<SuccessResponse<ProviderListResponse>>());
        expect((result as SuccessResponse<ProviderListResponse>).data, equals(providers));
        verify(
          () => mockClient.get<ProviderListResponse>(
            "/provider",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });

      test("error: propagates API error from GET /provider", () async {
        final error = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "Not Found");
        when(
          () => mockClient.get<ProviderListResponse>(
            "/provider",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.listProviders();

        expect(result, isA<ErrorResponse<ProviderListResponse>>());
        expect((result as ErrorResponse<ProviderListResponse>).error, equals(error));
        verify(
          () => mockClient.get<ProviderListResponse>(
            "/provider",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });
    });

    // -----------------------------------------------------------------------
    // session listing
    // -----------------------------------------------------------------------

    group("listSessions", () {
      test("success: returns List<Session> from GET /session", () async {
        final sessions = [testSession()];
        when(
          () => mockClient.get<List<Session>>(
            "/session",
            fromJson: any(named: "fromJson"),
            headers: any(named: "headers"),
            queryParameters: any(named: "queryParameters"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(sessions));

        final result = await sessionService.listSessions(projectId: "/tmp/project");

        expect(result, isA<SuccessResponse<List<Session>>>());
        expect((result as SuccessResponse<List<Session>>).data, equals(sessions));
      });

      test("error: propagates API error from GET /session", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.get<List<Session>>(
            "/session",
            fromJson: any(named: "fromJson"),
            headers: any(named: "headers"),
            queryParameters: any(named: "queryParameters"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.listSessions(projectId: "/tmp/project");

        expect(result, isA<ErrorResponse<List<Session>>>());
        expect((result as ErrorResponse<List<Session>>).error, equals(error));
      });

      test("passes x-project-id header and roots=true query parameter to GET /session", () async {
        when(
          () => mockClient.get<List<Session>>(
            any(),
            fromJson: any(named: "fromJson"),
            headers: any(named: "headers"),
            queryParameters: any(named: "queryParameters"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(<Session>[]));

        await sessionService.listSessions(projectId: "/tmp/project");

        verify(
          () => mockClient.get<List<Session>>(
            "/session",
            fromJson: any(named: "fromJson"),
            headers: {"x-project-id": "/tmp/project"},
          ),
        ).called(1);
      });
    });

    // -----------------------------------------------------------------------
    // session CRUD
    // -----------------------------------------------------------------------

    group("createSessionWithMessage", () {
      test("success: returns Session from POST /session", () async {
        final created = testSession(id: "server-session-id");
        when(
          () => mockClient.post<Session>(
            "/session",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(created));

        final result = await sessionService.createSessionWithMessage(
          projectId: "/tmp/project",
          text: "hello",
          agent: null,
          model: null,
          dedicatedWorktree: true,
        );

        expect(result, isA<SuccessResponse<Session>>());
        expect((result as SuccessResponse<Session>).data.id, equals("server-session-id"));
        verify(
          () => mockClient.post<Session>(
            "/session",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /session", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<Session>(
            "/session",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.createSessionWithMessage(
          projectId: "/tmp/project",
          text: "hello",
          agent: null,
          model: null,
          dedicatedWorktree: true,
        );

        expect(result, isA<ErrorResponse<Session>>());
        expect((result as ErrorResponse<Session>).error, equals(error));
        verify(
          () => mockClient.post<Session>(
            "/session",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("sends projectId + prompt parts and optional fields in body", () async {
        when(
          () => mockClient.post<Session>(
            any(),
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s1")));

        await sessionService.createSessionWithMessage(
          projectId: "/tmp/project",
          text: "first prompt",
          agent: null,
          model: null,
          dedicatedWorktree: true,
        );

        final captured =
            verify(
                  () => mockClient.post<Session>(
                    "/session",
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as Map<String, dynamic>;
        expect(
          captured,
          equals({
            "projectId": "/tmp/project",
            "parts": [
              {"text": "first prompt", "type": "text"},
            ],
            "agent": null,
            "model": null,
            "dedicatedWorktree": true,
          }),
        );
      });
    });

    group("archiveSession", () {
      const sessionId = "session-42";

      test("success: returns Session from PATCH /session/:id", () async {
        final session = testSession(id: sessionId);
        when(
          () => mockClient.patch<Session>(
            "/session/$sessionId",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(session));

        final result = await sessionService.archiveSession(
          sessionId: sessionId,
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        );

        expect(result, isA<SuccessResponse<Session>>());
        expect((result as SuccessResponse<Session>).data, equals(session));
        verify(
          () => mockClient.patch<Session>(
            "/session/$sessionId",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from PATCH /session/:id", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.patch<Session>(
            "/session/$sessionId",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.archiveSession(
          sessionId: sessionId,
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        );

        expect(result, isA<ErrorResponse<Session>>());
        expect((result as ErrorResponse<Session>).error, equals(error));
      });

      test("sends archived timestamp in body to PATCH /session/:id", () async {
        when(
          () => mockClient.patch<Session>(
            "/session/$sessionId",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession()));

        await sessionService.archiveSession(
          sessionId: sessionId,
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        );

        final captured =
            verify(
                  () => mockClient.patch<Session>(
                    "/session/$sessionId",
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as Map<String, dynamic>;

        expect(captured["archived"], isTrue);
      });
    });

    group("unarchiveSession", () {
      const sessionId = "session-99";

      test("success: returns Session from PATCH /session/:id", () async {
        final session = testSession(id: sessionId);
        when(
          () => mockClient.patch<Session>(
            "/session/$sessionId",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(session));

        final result = await sessionService.unarchiveSession(sessionId);

        expect(result, isA<SuccessResponse<Session>>());
        expect((result as SuccessResponse<Session>).data, equals(session));
        verify(
          () => mockClient.patch<Session>(
            "/session/$sessionId",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from PATCH /session/:id", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.patch<Session>(
            "/session/$sessionId",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.unarchiveSession(sessionId);

        expect(result, isA<ErrorResponse<Session>>());
        expect((result as ErrorResponse<Session>).error, equals(error));
      });

      test("sends null archived value in body to PATCH /session/:id", () async {
        when(
          () => mockClient.patch<Session>(
            "/session/$sessionId",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession()));

        await sessionService.unarchiveSession(sessionId);

        final captured =
            verify(
                  () => mockClient.patch<Session>(
                    "/session/$sessionId",
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as Map<String, dynamic>;

        expect(captured["archived"], isFalse);
      });
    });

    group("renameSession", () {
      const sessionId = "session-rename";

      test("success: returns Session from PATCH /session/title", () async {
        final session = testSession(id: sessionId);
        when(
          () => mockClient.patch<Session>(
            "/session/title",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(session));

        final result = await sessionService.renameSession(sessionId: sessionId, title: "New Title");

        expect(result, isA<SuccessResponse<Session>>());
        expect((result as SuccessResponse<Session>).data, equals(session));
        verify(
          () => mockClient.patch<Session>(
            "/session/title",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from PATCH /session/title", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.patch<Session>(
            "/session/title",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.renameSession(sessionId: sessionId, title: "New Title");

        expect(result, isA<ErrorResponse<Session>>());
        expect((result as ErrorResponse<Session>).error, equals(error));
      });

      test("sends sessionId and title in body to PATCH /session/title", () async {
        when(
          () => mockClient.patch<Session>(
            "/session/title",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession()));

        await sessionService.renameSession(sessionId: sessionId, title: "Updated Title");

        final captured =
            verify(
                  () => mockClient.patch<Session>(
                    "/session/title",
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as Map<String, dynamic>;

        expect(captured["sessionId"], equals(sessionId));
        expect(captured["title"], equals("Updated Title"));
      });
    });

    group("deleteSession", () {
      const sessionId = "session-del";

      test("success: returns true from DELETE /session/:id", () async {
        when(
          () => mockClient.delete<bool>(
            "/session/$sessionId",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(true));

        final result = await sessionService.deleteSession(
          sessionId: sessionId,
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        );

        expect(result, isA<SuccessResponse<bool>>());
        expect((result as SuccessResponse<bool>).data, isTrue);
        verify(
          () => mockClient.delete<bool>(
            "/session/$sessionId",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from DELETE /session/:id", () async {
        final error = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "Not Found");
        when(
          () => mockClient.delete<bool>(
            "/session/$sessionId",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.deleteSession(
          sessionId: sessionId,
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        );

        expect(result, isA<ErrorResponse<bool>>());
        expect((result as ErrorResponse<bool>).error, equals(error));
        verify(
          () => mockClient.delete<bool>(
            "/session/$sessionId",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });
    });

    // -----------------------------------------------------------------------
    // session data
    // -----------------------------------------------------------------------

    group("getChildren", () {
      const sessionId = "session-parent";

      test("success: returns List<Session> from GET /session/:id/children", () async {
        final children = [testSession(id: "child-1"), testSession(id: "child-2")];
        when(
          () => mockClient.get<List<Session>>(
            "/session/$sessionId/children",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(children));

        final result = await sessionService.getChildren(sessionId);

        expect(result, isA<SuccessResponse<List<Session>>>());
        expect((result as SuccessResponse<List<Session>>).data, equals(children));
        verify(
          () => mockClient.get<List<Session>>(
            "/session/$sessionId/children",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });

      test("error: propagates API error from GET /session/:id/children", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.get<List<Session>>(
            "/session/$sessionId/children",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.getChildren(sessionId);

        expect(result, isA<ErrorResponse<List<Session>>>());
        expect((result as ErrorResponse<List<Session>>).error, equals(error));
        verify(
          () => mockClient.get<List<Session>>(
            "/session/$sessionId/children",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });
    });

    group("getSessionStatuses", () {
      test("success: returns Map<String, SessionStatus> from GET /session/status", () async {
        when(
          () => mockClient.get<Map<String, SessionStatus>>(
            "/session/status",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(<String, SessionStatus>{}));

        final result = await sessionService.getSessionStatuses();

        expect(result, isA<SuccessResponse<Map<String, SessionStatus>>>());
        verify(
          () => mockClient.get<Map<String, SessionStatus>>(
            "/session/status",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });

      test("error: propagates API error from GET /session/status", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.get<Map<String, SessionStatus>>(
            "/session/status",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.getSessionStatuses();

        expect(result, isA<ErrorResponse<Map<String, SessionStatus>>>());
        expect((result as ErrorResponse<Map<String, SessionStatus>>).error, equals(error));
        verify(
          () => mockClient.get<Map<String, SessionStatus>>(
            "/session/status",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });
    });

    group("getMessages", () {
      const sessionId = "session-msg";

      test("success: returns List<MessageWithParts> from GET /session/:id/message", () async {
        final messages = [testMessageWithParts()];
        when(
          () => mockClient.get<List<MessageWithParts>>(
            "/session/$sessionId/message",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(messages));

        final result = await sessionService.getMessages(sessionId);

        expect(result, isA<SuccessResponse<List<MessageWithParts>>>());
        expect((result as SuccessResponse<List<MessageWithParts>>).data, equals(messages));
        verify(
          () => mockClient.get<List<MessageWithParts>>(
            "/session/$sessionId/message",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });

      test("error: propagates API error from GET /session/:id/message", () async {
        final error = ApiError.dartHttpClient(Exception("Timeout"));
        when(
          () => mockClient.get<List<MessageWithParts>>(
            "/session/$sessionId/message",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.getMessages(sessionId);

        expect(result, isA<ErrorResponse<List<MessageWithParts>>>());
        expect((result as ErrorResponse<List<MessageWithParts>>).error, equals(error));
        verify(
          () => mockClient.get<List<MessageWithParts>>(
            "/session/$sessionId/message",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });
    });

    // -----------------------------------------------------------------------
    // messaging
    // -----------------------------------------------------------------------

    group("sendMessage", () {
      const sessionId = "session-send";

      test("success: returns true from POST /session/:id/prompt_async", () async {
        when(
          () => mockClient.post<bool>(
            "/session/$sessionId/prompt_async",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(true));

        final result = await sessionService.sendMessage(sessionId, "Hello");

        expect(result, isA<SuccessResponse<bool>>());
        expect((result as SuccessResponse<bool>).data, isTrue);
        verify(
          () => mockClient.post<bool>(
            "/session/$sessionId/prompt_async",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /session/:id/prompt_async", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<bool>(
            "/session/$sessionId/prompt_async",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.sendMessage(sessionId, "Hello");

        expect(result, isA<ErrorResponse<bool>>());
        expect((result as ErrorResponse<bool>).error, equals(error));
      });

      test("body contains text parts and omits agent/model when no optional params provided", () async {
        when(
          () => mockClient.post<bool>(
            any(),
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(true));

        await sessionService.sendMessage(sessionId, "Hello, world!");

        final captured =
            verify(
                  () => mockClient.post<bool>(
                    any(),
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as Map<String, dynamic>;

        expect(
          captured["parts"],
          equals([
            {"type": "text", "text": "Hello, world!"},
          ]),
        );
        expect(captured["agent"], isNull);
        expect(captured["model"], isNull);
      });

      test("body includes agent and model when all optional params provided", () async {
        when(
          () => mockClient.post<bool>(
            any(),
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(true));

        await sessionService.sendMessage(
          sessionId,
          "Write a test",
          agent: "coder",
          providerID: "anthropic",
          modelID: "claude-3-5-sonnet",
        );

        final captured =
            verify(
                  () => mockClient.post<bool>(
                    any(),
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as Map<String, dynamic>;

        expect(captured["agent"], equals("coder"));
        expect(
          captured["model"],
          equals({"providerID": "anthropic", "modelID": "claude-3-5-sonnet"}),
        );
      });
    });

    group("abortSession", () {
      const sessionId = "session-abort";

      test("success: returns true from POST /session/:id/abort", () async {
        when(
          () => mockClient.post<bool>(
            "/session/$sessionId/abort",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(true));

        final result = await sessionService.abortSession(sessionId);

        expect(result, isA<SuccessResponse<bool>>());
        expect((result as SuccessResponse<bool>).data, isTrue);
        verify(
          () => mockClient.post<bool>(
            "/session/$sessionId/abort",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /session/:id/abort", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<bool>(
            "/session/$sessionId/abort",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.abortSession(sessionId);

        expect(result, isA<ErrorResponse<bool>>());
        expect((result as ErrorResponse<bool>).error, equals(error));
        verify(
          () => mockClient.post<bool>(
            "/session/$sessionId/abort",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });
    });

    // -----------------------------------------------------------------------
    // questions
    // -----------------------------------------------------------------------

    group("getPendingQuestions", () {
      const sessionId = "session-q";

      test("success: returns List<PendingQuestion> from GET /session/:id/questions", () async {
        final questions = [testPendingQuestion()];
        when(
          () => mockClient.get<List<PendingQuestion>>(
            "/session/$sessionId/questions",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(questions));

        final result = await sessionService.getPendingQuestions(sessionId);

        expect(result, isA<SuccessResponse<List<PendingQuestion>>>());
        expect((result as SuccessResponse<List<PendingQuestion>>).data, equals(questions));
        verify(
          () => mockClient.get<List<PendingQuestion>>(
            "/session/$sessionId/questions",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });

      test("error: propagates API error from GET /session/:id/questions", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.get<List<PendingQuestion>>(
            "/session/$sessionId/questions",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.getPendingQuestions(sessionId);

        expect(result, isA<ErrorResponse<List<PendingQuestion>>>());
        expect((result as ErrorResponse<List<PendingQuestion>>).error, equals(error));
        verify(
          () => mockClient.get<List<PendingQuestion>>(
            "/session/$sessionId/questions",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });
    });

    group("replyToQuestion", () {
      const requestId = "request-1";

      test("success: returns true from POST /question/:id/reply", () async {
        when(
          () => mockClient.post<bool>(
            "/question/$requestId/reply",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(true));

        final result = await sessionService.replyToQuestion(
          requestId: requestId,
          sessionId: "test-session",
          answers: [
            const ReplyAnswer(values: ["Yes"]),
            const ReplyAnswer(values: ["Proceed"]),
          ],
        );

        expect(result, isA<SuccessResponse<bool>>());
        expect((result as SuccessResponse<bool>).data, isTrue);
        verify(
          () => mockClient.post<bool>(
            "/question/$requestId/reply",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /question/:id/reply", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<bool>(
            "/question/$requestId/reply",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.replyToQuestion(
          requestId: requestId,
          sessionId: "test-session",
          answers: [],
        );

        expect(result, isA<ErrorResponse<bool>>());
        expect((result as ErrorResponse<bool>).error, equals(error));
      });

      test("sends answers list in body to POST /question/:id/reply", () async {
        const answers = [
          ReplyAnswer(values: ["Yes"]),
          ReplyAnswer(values: ["No"]),
        ];
        when(
          () => mockClient.post<bool>(
            any(),
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(true));

        await sessionService.replyToQuestion(requestId: requestId, sessionId: "test-session", answers: answers);

        final captured =
            verify(
                  () => mockClient.post<bool>(
                    any(),
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as Map<String, dynamic>;

        expect(
          captured["answers"],
          equals([
            {
              "values": ["Yes"],
            },
            {
              "values": ["No"],
            },
          ]),
        );
      });
    });

    group("rejectQuestion", () {
      const requestId = "request-reject";

      test("success: returns true from POST /question/:id/reject", () async {
        when(
          () => mockClient.post<bool>(
            "/question/$requestId/reject",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(true));

        final result = await sessionService.rejectQuestion(requestId);

        expect(result, isA<SuccessResponse<bool>>());
        expect((result as SuccessResponse<bool>).data, isTrue);
        verify(
          () => mockClient.post<bool>(
            "/question/$requestId/reject",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /question/:id/reject", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<bool>(
            "/question/$requestId/reject",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.rejectQuestion(requestId);

        expect(result, isA<ErrorResponse<bool>>());
        expect((result as ErrorResponse<bool>).error, equals(error));
        verify(
          () => mockClient.post<bool>(
            "/question/$requestId/reject",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });
    });
  });
}
