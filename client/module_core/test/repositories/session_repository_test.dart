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
    when(() => api.getPendingPermissions(sessionId: "session-1")).thenAnswer(
      (_) async => ApiResponse.success(const PendingPermissionResponse(data: <PendingPermission>[])),
    );
    when(() => api.getChildren(sessionId: "session-1")).thenAnswer(
      (_) async => ApiResponse.success(const SessionListResponse(items: <Session>[])),
    );
    when(api.getSessionStatuses).thenAnswer(
      (_) async => ApiResponse.success(const SessionStatusResponse(statuses: <String, SessionStatus>{})),
    );
    when(
      () => api.listAgents(projectId: any(named: "projectId")),
    ).thenAnswer((_) async => ApiResponse.success(const Agents(agents: <AgentInfo>[])));
    when(() => api.listProviders(projectId: any(named: "projectId"))).thenAnswer(
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
    when(
      () => api.rejectQuestion(requestId: "question-1", sessionId: "session-1"),
    ).thenAnswer((_) async => ApiResponse.success(null));
    await repository.getMessages(sessionId: "session-1");
    await repository.getPendingQuestions(sessionId: "session-1");
    await repository.getPendingPermissions(sessionId: "session-1");
    await repository.getChildren(sessionId: "session-1");
    await repository.getSessionStatuses();
    await repository.listAgents(projectId: "project-1");
    await repository.listProviders(projectId: "project-1");
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
    await repository.rejectQuestion(requestId: "question-1", sessionId: "session-1");
    verify(() => api.getMessages(sessionId: "session-1")).called(1);
    verify(() => api.getPendingQuestions(sessionId: "session-1")).called(1);
    verify(() => api.getPendingPermissions(sessionId: "session-1")).called(1);
    verify(() => api.getChildren(sessionId: "session-1")).called(1);
    verify(api.getSessionStatuses).called(1);
    verify(() => api.listAgents(projectId: "project-1")).called(1);
    verify(() => api.listProviders(projectId: "project-1")).called(1);
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
    verify(() => api.rejectQuestion(requestId: "question-1", sessionId: "session-1")).called(1);
  });

  test("listProviders does not cache an empty response but caches one with models", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);

    const emptyProviders = ProviderListResponse(connectedOnly: false, items: <ProviderInfo>[]);
    const populatedProviders = ProviderListResponse(
      connectedOnly: false,
      items: [
        ProviderInfo(
          id: "cursor",
          name: "Cursor",
          defaultModelID: "auto",
          models: {
            "auto": ProviderModel(
              id: "auto",
              providerID: "cursor",
              name: "Auto",
              variants: <String>[],
              family: null,
              releaseDate: null,
            ),
          },
        ),
      ],
    );

    // First fetch returns an empty catalog (e.g. the ACP backend has not warmed
    // its model list yet); later fetches return the populated catalog.
    var calls = 0;
    when(() => api.listProviders(projectId: "p1")).thenAnswer((_) async {
      calls++;
      return ApiResponse.success(calls == 1 ? emptyProviders : populatedProviders);
    });

    final first = await repository.listProviders(projectId: "p1");
    expect((first as SuccessResponse<ProviderListResponse>).data.items, isEmpty);

    // The empty result must NOT be cached: the second fetch hits the API again
    // and returns the now-populated catalog (the regression being guarded).
    final second = await repository.listProviders(projectId: "p1");
    expect((second as SuccessResponse<ProviderListResponse>).data.items, isNotEmpty);
    verify(() => api.listProviders(projectId: "p1")).called(2);

    // The populated result IS cached: the third fetch is served without the API.
    final third = await repository.listProviders(projectId: "p1");
    expect((third as SuccessResponse<ProviderListResponse>).data.items, isNotEmpty);
    verifyNever(() => api.listProviders(projectId: "p1"));
  });

  test("listProviders does not cache a partially populated multi-provider response", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);

    ProviderInfo provider({required String id, required bool withModels}) => ProviderInfo(
          id: id,
          name: id,
          defaultModelID: withModels ? "$id-default" : null,
          models: withModels
              ? {
                  "$id-default": ProviderModel(
                    id: "$id-default",
                    providerID: id,
                    name: "$id default",
                    variants: <String>[],
                    family: null,
                    releaseDate: null,
                  ),
                }
              : const <String, ProviderModel>{},
        );

    // A fast provider is already populated while a slow one (e.g. Cursor/ACP) is
    // still warming up with an empty models map; once warmed, both are populated.
    const connectedOnly = true;
    final partialProviders = ProviderListResponse(
      connectedOnly: connectedOnly,
      items: [provider(id: "openai", withModels: true), provider(id: "cursor", withModels: false)],
    );
    final fullProviders = ProviderListResponse(
      connectedOnly: connectedOnly,
      items: [provider(id: "openai", withModels: true), provider(id: "cursor", withModels: true)],
    );

    var calls = 0;
    when(() => api.listProviders(projectId: "p1")).thenAnswer((_) async {
      calls++;
      return ApiResponse.success(calls == 1 ? partialProviders : fullProviders);
    });

    // The partial response must NOT be cached, even though one provider has
    // models — otherwise the warming provider's picker would stay blank forever.
    final first = await repository.listProviders(projectId: "p1");
    final firstItems = (first as SuccessResponse<ProviderListResponse>).data.items;
    expect(firstItems.firstWhere((p) => p.id == "cursor").models, isEmpty);

    // Next fetch hits the API again and returns the now-fully-populated catalog.
    final second = await repository.listProviders(projectId: "p1");
    final secondItems = (second as SuccessResponse<ProviderListResponse>).data.items;
    expect(secondItems.firstWhere((p) => p.id == "cursor").models, isNotEmpty);
    verify(() => api.listProviders(projectId: "p1")).called(2);

    // The fully-populated result IS cached: the third fetch is served from cache.
    await repository.listProviders(projectId: "p1");
    verifyNever(() => api.listProviders(projectId: "p1"));
  });
}
