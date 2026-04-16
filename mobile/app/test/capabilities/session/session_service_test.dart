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
      test("success: returns Agents from GET /agent", () async {
        final agents = Agents(agents: [testAgentInfo()]);
        when(
          () => mockClient.get<Agents>(
            "/agent",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(agents));

        final result = await sessionService.listAgents();

        expect(result, isA<SuccessResponse<Agents>>());
        expect((result as SuccessResponse<Agents>).data, equals(agents));
        verify(
          () => mockClient.get<Agents>(
            "/agent",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });

      test("error: propagates API error from GET /agent", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.get<Agents>(
            "/agent",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.listAgents();

        expect(result, isA<ErrorResponse<Agents>>());
        expect((result as ErrorResponse<Agents>).error, equals(error));
        verify(
          () => mockClient.get<Agents>(
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
      test("success: returns SessionListResponse from POST /sessions", () async {
        final sessions = SessionListResponse(items: [testSession()]);
        when(
          () => mockClient.post<SessionListResponse>(
            "/sessions",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(sessions));

        final result = await sessionService.listSessions(projectId: "/tmp/project");

        expect(result, isA<SuccessResponse<SessionListResponse>>());
        expect((result as SuccessResponse<SessionListResponse>).data, equals(sessions));
      });

      test("error: propagates API error from POST /sessions", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<SessionListResponse>(
            "/sessions",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.listSessions(projectId: "/tmp/project");

        expect(result, isA<ErrorResponse<SessionListResponse>>());
        expect((result as ErrorResponse<SessionListResponse>).error, equals(error));
      });

      test("sends projectId in SessionListRequest body to POST /sessions", () async {
        when(
          () => mockClient.post<SessionListResponse>(
            any(),
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: [])));

        await sessionService.listSessions(projectId: "/tmp/project");

        verify(
          () => mockClient.post<SessionListResponse>(
            "/sessions",
            fromJson: any(named: "fromJson"),
            body: const SessionListRequest(projectId: "/tmp/project", start: null, limit: null),
          ),
        ).called(1);
      });
    });

    // -----------------------------------------------------------------------
    // session CRUD
    // -----------------------------------------------------------------------

    group("createSessionWithMessage", () {
      test("success: returns Session from POST /session/create", () async {
        final created = testSession(id: "server-session-id");
        when(
          () => mockClient.post<Session>(
            "/session/create",
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
            "/session/create",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /session/create", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<Session>(
            "/session/create",
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
            "/session/create",
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
                    "/session/create",
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as CreateSessionRequest;
        expect(
          captured,
          equals(
            const CreateSessionRequest(
              projectId: "/tmp/project",
              parts: [PromptPart.text(text: "first prompt")],
              agent: null,
              model: null,
              dedicatedWorktree: true,
            ),
          ),
        );
      });
    });

    group("archiveSession", () {
      const sessionId = "session-42";

      test("success: returns Session from PATCH /session/update/archive", () async {
        final session = testSession(id: sessionId);
        when(
          () => mockClient.patch<Session>(
            "/session/update/archive",
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
            "/session/update/archive",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from PATCH /session/update/archive", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.patch<Session>(
            "/session/update/archive",
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

      test("sends archive request body to PATCH /session/update/archive", () async {
        when(
          () => mockClient.patch<Session>(
            "/session/update/archive",
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
                    "/session/update/archive",
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as UpdateSessionArchiveRequest;

        expect(captured.archived, isTrue);
        expect(captured.sessionId, equals(sessionId));
      });
    });

    group("unarchiveSession", () {
      const sessionId = "session-99";

      test("success: returns Session from PATCH /session/update/archive", () async {
        final session = testSession(id: sessionId);
        when(
          () => mockClient.patch<Session>(
            "/session/update/archive",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(session));

        final result = await sessionService.unarchiveSession(sessionId);

        expect(result, isA<SuccessResponse<Session>>());
        expect((result as SuccessResponse<Session>).data, equals(session));
        verify(
          () => mockClient.patch<Session>(
            "/session/update/archive",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from PATCH /session/update/archive", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.patch<Session>(
            "/session/update/archive",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.unarchiveSession(sessionId);

        expect(result, isA<ErrorResponse<Session>>());
        expect((result as ErrorResponse<Session>).error, equals(error));
      });

      test("sends unarchive request body to PATCH /session/update/archive", () async {
        when(
          () => mockClient.patch<Session>(
            "/session/update/archive",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession()));

        await sessionService.unarchiveSession(sessionId);

        final captured =
            verify(
                  () => mockClient.patch<Session>(
                    "/session/update/archive",
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as UpdateSessionArchiveRequest;

        expect(captured.archived, isFalse);
        expect(captured.sessionId, equals(sessionId));
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
                as RenameSessionRequest;

        expect(captured.sessionId, equals(sessionId));
        expect(captured.title, equals("Updated Title"));
      });
    });

    group("deleteSession", () {
      const sessionId = "session-del";

      test("success: returns void from DELETE /session/delete", () async {
        when(
          () => mockClient.delete<SuccessEmptyResponse>(
            "/session/delete",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(const SuccessEmptyResponse()));

        final result = await sessionService.deleteSession(
          sessionId: sessionId,
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        );

        expect(result, isA<SuccessResponse<void>>());
        verify(
          () => mockClient.delete<SuccessEmptyResponse>(
            "/session/delete",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from DELETE /session/delete", () async {
        final error = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "Not Found");
        when(
          () => mockClient.delete<SuccessEmptyResponse>(
            "/session/delete",
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

        expect(result, isA<ErrorResponse<void>>());
        expect((result as ErrorResponse<void>).error, equals(error));
        verify(
          () => mockClient.delete<SuccessEmptyResponse>(
            "/session/delete",
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

      test("success: returns SessionListResponse from POST /session/children", () async {
        final children = SessionListResponse(
          items: [
            testSession(id: "child-1"),
            testSession(id: "child-2"),
          ],
        );
        when(
          () => mockClient.post<SessionListResponse>(
            "/session/children",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(children));

        final result = await sessionService.getChildren(sessionId);

        expect(result, isA<SuccessResponse<SessionListResponse>>());
        expect((result as SuccessResponse<SessionListResponse>).data, equals(children));
        verify(
          () => mockClient.post<SessionListResponse>(
            "/session/children",
            fromJson: any(named: "fromJson"),
            body: const SessionIdRequest(sessionId: sessionId),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /session/children", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<SessionListResponse>(
            "/session/children",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.getChildren(sessionId);

        expect(result, isA<ErrorResponse<SessionListResponse>>());
        expect((result as ErrorResponse<SessionListResponse>).error, equals(error));
        verify(
          () => mockClient.post<SessionListResponse>(
            "/session/children",
            fromJson: any(named: "fromJson"),
            body: const SessionIdRequest(sessionId: sessionId),
          ),
        ).called(1);
      });
    });

    group("getSessionStatuses", () {
      test("success: returns SessionStatusResponse from GET /session/status", () async {
        when(
          () => mockClient.get<SessionStatusResponse>(
            "/session/status",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(const SessionStatusResponse(statuses: {})));

        final result = await sessionService.getSessionStatuses();

        expect(result, isA<SuccessResponse<SessionStatusResponse>>());
        verify(
          () => mockClient.get<SessionStatusResponse>(
            "/session/status",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });

      test("error: propagates API error from GET /session/status", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.get<SessionStatusResponse>(
            "/session/status",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.getSessionStatuses();

        expect(result, isA<ErrorResponse<SessionStatusResponse>>());
        expect((result as ErrorResponse<SessionStatusResponse>).error, equals(error));
        verify(
          () => mockClient.get<SessionStatusResponse>(
            "/session/status",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });
    });

    group("getMessages", () {
      const sessionId = "session-msg";

      test("success: returns MessageWithPartsResponse from POST /session/messages", () async {
        final messages = MessageWithPartsResponse(messages: [testMessageWithParts()]);
        when(
          () => mockClient.post<MessageWithPartsResponse>(
            "/session/messages",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(messages));

        final result = await sessionService.getMessages(sessionId);

        expect(result, isA<SuccessResponse<MessageWithPartsResponse>>());
        expect((result as SuccessResponse<MessageWithPartsResponse>).data, equals(messages));
        verify(
          () => mockClient.post<MessageWithPartsResponse>(
            "/session/messages",
            fromJson: any(named: "fromJson"),
            body: const SessionIdRequest(sessionId: sessionId),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /session/messages", () async {
        final error = ApiError.dartHttpClient(Exception("Timeout"));
        when(
          () => mockClient.post<MessageWithPartsResponse>(
            "/session/messages",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.getMessages(sessionId);

        expect(result, isA<ErrorResponse<MessageWithPartsResponse>>());
        expect((result as ErrorResponse<MessageWithPartsResponse>).error, equals(error));
        verify(
          () => mockClient.post<MessageWithPartsResponse>(
            "/session/messages",
            fromJson: any(named: "fromJson"),
            body: const SessionIdRequest(sessionId: sessionId),
          ),
        ).called(1);
      });
    });

    // -----------------------------------------------------------------------
    // messaging
    // -----------------------------------------------------------------------

    group("sendMessage", () {
      const sessionId = "session-send";

      test("success: returns void from POST /session/prompt_async", () async {
        when(
          () => mockClient.post<void>(
            "/session/prompt_async",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(null));

        final result = await sessionService.sendMessage(sessionId, "Hello");

        expect(result, isA<SuccessResponse<void>>());
        verify(
          () => mockClient.post<void>(
            "/session/prompt_async",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /session/prompt_async", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<void>(
            "/session/prompt_async",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.sendMessage(sessionId, "Hello");

        expect(result, isA<ErrorResponse<void>>());
        expect((result as ErrorResponse<void>).error, equals(error));
      });

      test("body contains text parts and omits agent/model when no optional params provided", () async {
        when(
          () => mockClient.post<void>(
            any(),
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(null));

        await sessionService.sendMessage(sessionId, "Hello, world!");

        final captured =
            verify(
                  () => mockClient.post<void>(
                    any(),
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as SendPromptRequest;

        expect(captured.parts, equals(const [PromptPart.text(text: "Hello, world!")]));
        expect(captured.agent, isNull);
        expect(captured.model, isNull);
        expect(captured.sessionId, equals(sessionId));
      });

      test("body includes agent and model when all optional params provided", () async {
        when(
          () => mockClient.post<void>(
            any(),
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(null));

        await sessionService.sendMessage(
          sessionId,
          "Write a test",
          agent: "coder",
          providerID: "anthropic",
          modelID: "claude-3-5-sonnet",
        );

        final captured =
            verify(
                  () => mockClient.post<void>(
                    any(),
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as SendPromptRequest;

        expect(captured.agent, equals("coder"));
        expect(captured.model, equals(const PromptModel(providerID: "anthropic", modelID: "claude-3-5-sonnet")));
        expect(captured.sessionId, equals(sessionId));
      });
    });

    group("abortSession", () {
      const sessionId = "session-abort";

      test("success: returns SuccessEmptyResponse from POST /session/abort", () async {
        when(
          () => mockClient.post<SuccessEmptyResponse>(
            "/session/abort",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(const SuccessEmptyResponse()));

        final result = await sessionService.abortSession(sessionId);

        expect(result, isA<SuccessResponse<SuccessEmptyResponse>>());
        verify(
          () => mockClient.post<SuccessEmptyResponse>(
            "/session/abort",
            fromJson: any(named: "fromJson"),
            body: const SessionIdRequest(sessionId: sessionId),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /session/abort", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<SuccessEmptyResponse>(
            "/session/abort",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.abortSession(sessionId);

        expect(result, isA<ErrorResponse<SuccessEmptyResponse>>());
        expect((result as ErrorResponse<SuccessEmptyResponse>).error, equals(error));
        verify(
          () => mockClient.post<SuccessEmptyResponse>(
            "/session/abort",
            fromJson: any(named: "fromJson"),
            body: const SessionIdRequest(sessionId: sessionId),
          ),
        ).called(1);
      });
    });

    // -----------------------------------------------------------------------
    // questions
    // -----------------------------------------------------------------------

    group("getPendingQuestions", () {
      const sessionId = "session-q";

      test("success: returns PendingQuestionResponse from POST /session/questions", () async {
        final questions = PendingQuestionResponse(data: [testPendingQuestion()]);
        when(
          () => mockClient.post<PendingQuestionResponse>(
            "/session/questions",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(questions));

        final result = await sessionService.getPendingQuestions(sessionId);

        expect(result, isA<SuccessResponse<PendingQuestionResponse>>());
        expect((result as SuccessResponse<PendingQuestionResponse>).data, equals(questions));
        verify(
          () => mockClient.post<PendingQuestionResponse>(
            "/session/questions",
            fromJson: any(named: "fromJson"),
            body: const SessionIdRequest(sessionId: sessionId),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /session/questions", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<PendingQuestionResponse>(
            "/session/questions",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.getPendingQuestions(sessionId);

        expect(result, isA<ErrorResponse<PendingQuestionResponse>>());
        expect((result as ErrorResponse<PendingQuestionResponse>).error, equals(error));
        verify(
          () => mockClient.post<PendingQuestionResponse>(
            "/session/questions",
            fromJson: any(named: "fromJson"),
            body: const SessionIdRequest(sessionId: sessionId),
          ),
        ).called(1);
      });
    });

    group("replyToQuestion", () {
      const requestId = "request-1";

      test("success: returns void from POST /question/reply", () async {
        when(
          () => mockClient.post<void>(
            "/question/reply",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(null));

        final result = await sessionService.replyToQuestion(
          requestId: requestId,
          sessionId: "test-session",
          answers: [
            const ReplyAnswer(values: ["Yes"]),
            const ReplyAnswer(values: ["Proceed"]),
          ],
        );

        expect(result, isA<SuccessResponse<void>>());
        verify(
          () => mockClient.post<void>(
            "/question/reply",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /question/reply", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<void>(
            "/question/reply",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.replyToQuestion(
          requestId: requestId,
          sessionId: "test-session",
          answers: [],
        );

        expect(result, isA<ErrorResponse<void>>());
        expect((result as ErrorResponse<void>).error, equals(error));
      });

      test("sends requestId, sessionId, and answers in body to POST /question/reply", () async {
        const answers = [
          ReplyAnswer(values: ["Yes"]),
          ReplyAnswer(values: ["No"]),
        ];
        when(
          () => mockClient.post<void>(
            any(),
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(null));

        await sessionService.replyToQuestion(requestId: requestId, sessionId: "test-session", answers: answers);

        final captured =
            verify(
                  () => mockClient.post<void>(
                    any(),
                    fromJson: any(named: "fromJson"),
                    body: captureAny(named: "body"),
                  ),
                ).captured.last
                as ReplyToQuestionRequest;

        expect(captured.requestId, equals(requestId));
        expect(captured.sessionId, equals("test-session"));
        expect(captured.answers, equals(answers));
      });
    });

    group("rejectQuestion", () {
      const requestId = "request-reject";

      test("success: returns void from POST /question/reject", () async {
        when(
          () => mockClient.post<void>(
            "/question/reject",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(null));

        final result = await sessionService.rejectQuestion(requestId);

        expect(result, isA<SuccessResponse<void>>());
        verify(
          () => mockClient.post<void>(
            "/question/reject",
            fromJson: any(named: "fromJson"),
            body: const RejectQuestionRequest(requestId: requestId),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /question/reject", () async {
        final error = ApiError.generic();
        when(
          () => mockClient.post<void>(
            "/question/reject",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.rejectQuestion(requestId);

        expect(result, isA<ErrorResponse<void>>());
        expect((result as ErrorResponse<void>).error, equals(error));
        verify(
          () => mockClient.post<void>(
            "/question/reject",
            fromJson: any(named: "fromJson"),
            body: const RejectQuestionRequest(requestId: requestId),
          ),
        ).called(1);
      });
    });
  });
}
