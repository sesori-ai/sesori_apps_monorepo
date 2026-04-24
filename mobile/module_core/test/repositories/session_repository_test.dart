import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  test("session detail flows route through session api and repository", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);

    when(() => api.getMessages(sessionId: "session-1")).thenAnswer(
      (_) async => ApiResponse.success(const MessageWithPartsResponse(messages: <MessageWithParts>[])),
    );
    when(() => api.getPendingQuestions(sessionId: "session-1")).thenAnswer(
      (_) async => ApiResponse.success(const PendingQuestionResponse(data: <PendingQuestion>[])),
    );
    when(() => api.getChildren(sessionId: "session-1")).thenAnswer(
      (_) async => ApiResponse.success(const SessionListResponse(items: <Session>[])),
    );
    when(api.getSessionStatuses).thenAnswer(
      (_) async => ApiResponse.success(const SessionStatusResponse(statuses: <String, SessionStatus>{})),
    );
    when(api.listAgents).thenAnswer((_) async => ApiResponse.success(const Agents(agents: <AgentInfo>[])));
    when(api.listProviders).thenAnswer(
      (_) async => ApiResponse.success(const ProviderListResponse(connectedOnly: false, items: <ProviderInfo>[])),
    );
    when(() => api.listCommands(projectId: "project-1")).thenAnswer(
      (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
    );
    when(
      () => api.sendMessage(
        sessionId: "session-1",
        text: "hello",
        agent: "build",
        model: const PromptModel(providerID: "openai", modelID: "gpt-4.1"),
        variant: const SessionVariant(id: "xhigh"),
        command: "review",
      ),
    ).thenAnswer((_) async => ApiResponse.success(null));
    when(
      () => api.abortSession(sessionId: "session-1"),
    ).thenAnswer((_) async => ApiResponse.success(const SuccessEmptyResponse()));
    when(
      () => api.replyToQuestion(
        requestId: "question-1",
        sessionId: "session-1",
        answers: const [
          ReplyAnswer(values: <String>["Yes"]),
        ],
      ),
    ).thenAnswer((_) async => ApiResponse.success(null));
    when(() => api.rejectQuestion(requestId: "question-1")).thenAnswer((_) async => ApiResponse.success(null));
    await repository.getMessages(sessionId: "session-1");
    await repository.getPendingQuestions(sessionId: "session-1");
    await repository.getChildren(sessionId: "session-1");
    await repository.getSessionStatuses();
    await repository.listAgents();
    await repository.listProviders();
    await repository.listCommands(projectId: "project-1");
    await repository.sendMessage(
      sessionId: "session-1",
      text: "hello",
      agent: "build",
      model: const PromptModel(providerID: "openai", modelID: "gpt-4.1"),
      variant: const SessionVariant(id: "xhigh"),
      command: "review",
    );
    await repository.abortSession(sessionId: "session-1");
    await repository.replyToQuestion(
      requestId: "question-1",
      sessionId: "session-1",
      answers: const [
        ReplyAnswer(values: <String>["Yes"]),
      ],
    );
    await repository.rejectQuestion(requestId: "question-1");
    verify(() => api.getMessages(sessionId: "session-1")).called(1);
    verify(() => api.getPendingQuestions(sessionId: "session-1")).called(1);
    verify(() => api.getChildren(sessionId: "session-1")).called(1);
    verify(api.getSessionStatuses).called(1);
    verify(api.listAgents).called(1);
    verify(api.listProviders).called(1);
    verify(() => api.listCommands(projectId: "project-1")).called(1);
    verify(
      () => api.sendMessage(
        sessionId: "session-1",
        text: "hello",
        agent: "build",
        model: const PromptModel(providerID: "openai", modelID: "gpt-4.1"),
        variant: const SessionVariant(id: "xhigh"),
        command: "review",
      ),
    ).called(1);
    verify(() => api.abortSession(sessionId: "session-1")).called(1);
    verify(
      () => api.replyToQuestion(
        requestId: "question-1",
        sessionId: "session-1",
        answers: const [
          ReplyAnswer(values: <String>["Yes"]),
        ],
      ),
    ).called(1);
    verify(() => api.rejectQuestion(requestId: "question-1")).called(1);
  });
}
