import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/foundation/models/session_options/session_options_request_mode.dart";
import "package:sesori_dart_core/src/repositories/models/session_options_repository_result.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

enum _LegacyOptionsFailureSource() { agents, providers, commands }

void main() {
  setUpAll(registerAllFallbackValues);

  test("recognizes the structured stale prompt options error", () {
    final error = ApiError.nonSuccessCode(
      errorCode: 409,
      rawErrorString: jsonEncode(
        const SendPromptErrorResponse(
          code: SendPromptErrorCode.staleSessionOptions,
          message: "unsupported agent",
        ).toJson(),
      ),
    );

    expect(SessionRepository.isStalePromptOptionsError(error: error), isTrue);
  });

  test("does not classify legacy plain-text send failures as stale options", () {
    final error = ApiError.nonSuccessCode(errorCode: 400, rawErrorString: "unsupported agent");

    expect(SessionRepository.isStalePromptOptionsError(error: error), isFalse);
  });

  test("session detail flows route through session api and repository", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);

    when(() => api.getMessages(sessionId: "session-1", limit: null, before: null)).thenAnswer(
      (_) async =>
          ApiResponse.success(
            const MessageWithPartsResponse(
              messages: <MessageWithParts>[],
              nextCursor: null,
              replayedPromptDefaults: null,
            ),
          ),
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
      () => api.listAgents(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(const Agents(agents: <AgentInfo>[])));
    when(
      () => api.listProviders(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(const ProviderListResponse(connectedOnly: false, items: <ProviderInfo>[])),
    );
    when(() => api.listCommands(projectId: "project-1", pluginId: "plugin-1")).thenAnswer(
      (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
    );
    when(
      () => api.sendMessage(promptId: any(named: "promptId"), 
        attachments: const [],
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
    await repository.getMessages(sessionId: "session-1", limit: null, before: null);
    await repository.getPendingQuestions(sessionId: "session-1");
    await repository.getPendingPermissions(sessionId: "session-1");
    await repository.getChildren(sessionId: "session-1");
    await repository.getSessionStatuses();
    await repository.listAgents(projectId: "project-1", pluginId: "plugin-1");
    await repository.listProviders(projectId: "project-1", pluginId: "plugin-1");
    await repository.listCommands(projectId: "project-1", pluginId: "plugin-1");
    await repository.sendMessage(promptId: "prompt-1", 
      attachments: const [],
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
    verify(() => api.getMessages(sessionId: "session-1", limit: null, before: null)).called(1);
    verify(() => api.getPendingQuestions(sessionId: "session-1")).called(1);
    verify(() => api.getPendingPermissions(sessionId: "session-1")).called(1);
    verify(() => api.getChildren(sessionId: "session-1")).called(1);
    verify(api.getSessionStatuses).called(1);
    verify(() => api.listAgents(projectId: "project-1", pluginId: "plugin-1")).called(1);
    verify(() => api.listProviders(projectId: "project-1", pluginId: "plugin-1")).called(1);
    verify(() => api.listCommands(projectId: "project-1", pluginId: "plugin-1")).called(1);
    verify(
      () => api.sendMessage(promptId: "prompt-1", 
        attachments: const [],
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

  test("listProviders always delegates because the bridge owns option caching", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);
    when(() => api.listProviders(projectId: "p1", pluginId: "plugin-1")).thenAnswer(
      (_) async => ApiResponse.success(
        const ProviderListResponse(connectedOnly: false, items: <ProviderInfo>[]),
      ),
    );

    await repository.listProviders(projectId: "p1", pluginId: "plugin-1");
    await repository.listProviders(projectId: "p1", pluginId: "plugin-1");

    verify(() => api.listProviders(projectId: "p1", pluginId: "plugin-1")).called(2);
  });

  test("loadLegacySessionOptions calls all three APIs and maps their catalogs", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);
    const agent = AgentInfo(
      name: "build",
      description: "Build",
      model: null,
      mode: AgentMode.primary,
    );
    const provider = ProviderInfo(
      id: "provider-1",
      name: "Provider One",
      models: <String, ProviderModel>{},
      defaultModelID: null,
    );
    final command = testCommandInfo();
    when(
      () => api.listAgents(projectId: "p1", pluginId: "plugin-1"),
    ).thenAnswer((_) async => ApiResponse.success(const Agents(agents: [agent])));
    when(
      () => api.listProviders(projectId: "p1", pluginId: "plugin-1"),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        const ProviderListResponse(connectedOnly: false, items: [provider]),
      ),
    );
    when(
      () => api.listCommands(projectId: "p1", pluginId: "plugin-1"),
    ).thenAnswer((_) async => ApiResponse.success(CommandListResponse(items: [command])));

    final result = await repository.loadLegacySessionOptions(projectId: "p1", pluginId: "plugin-1");

    expect(
      result,
      isA<LegacySessionOptionsRepositoryAvailable>()
          .having((value) => value.catalog.agents, "agents", const [agent])
          .having((value) => value.catalog.providers, "providers", const [provider])
          .having((value) => value.catalog.providersConnectedOnly, "connectedOnly", isFalse)
          .having((value) => value.catalog.commands, "commands", [command]),
    );
    verify(() => api.listAgents(projectId: "p1", pluginId: "plugin-1")).called(1);
    verify(() => api.listProviders(projectId: "p1", pluginId: "plugin-1")).called(1);
    verify(() => api.listCommands(projectId: "p1", pluginId: "plugin-1")).called(1);
  });

  test("loadLegacySessionOptions preserves successful sources after each API failure", () async {
    for (final failureSource in _LegacyOptionsFailureSource.values) {
      final api = MockSessionApi();
      final repository = SessionRepository(api: api);
      final error = ApiError.generic();
      when(
        () => api.listAgents(projectId: "p1", pluginId: "plugin-1"),
      ).thenAnswer(
        (_) async => failureSource == _LegacyOptionsFailureSource.agents
            ? ApiResponse<Agents>.error(error)
            : ApiResponse.success(const Agents(agents: [])),
      );
      when(
        () => api.listProviders(projectId: "p1", pluginId: "plugin-1"),
      ).thenAnswer(
        (_) async => failureSource == _LegacyOptionsFailureSource.providers
            ? ApiResponse<ProviderListResponse>.error(error)
            : ApiResponse.success(const ProviderListResponse(connectedOnly: false, items: [])),
      );
      when(
        () => api.listCommands(projectId: "p1", pluginId: "plugin-1"),
      ).thenAnswer(
        (_) async => failureSource == _LegacyOptionsFailureSource.commands
            ? ApiResponse<CommandListResponse>.error(error)
            : ApiResponse.success(const CommandListResponse(items: [])),
      );

      final result = await repository.loadLegacySessionOptions(projectId: "p1", pluginId: "plugin-1");

      expect(
        result,
        isA<LegacySessionOptionsRepositoryPartial>()
            .having((value) => value.errors.single.source.name, "source", failureSource.name)
            .having((value) => value.errors.single.error, "error", error),
        reason: "failed to map $failureSource",
      );
      verify(() => api.listAgents(projectId: "p1", pluginId: "plugin-1")).called(1);
      verify(() => api.listProviders(projectId: "p1", pluginId: "plugin-1")).called(1);
      verify(() => api.listCommands(projectId: "p1", pluginId: "plugin-1")).called(1);
    }
  });

  test("loadLegacySessionOptions preserves every source error", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);
    final agentsError = ApiError.generic();
    final commandsError = ApiError.generic();
    when(
      () => api.listAgents(projectId: "p1", pluginId: "plugin-1"),
    ).thenAnswer((_) async => ApiResponse<Agents>.error(agentsError));
    when(
      () => api.listProviders(projectId: "p1", pluginId: "plugin-1"),
    ).thenAnswer(
      (_) async => ApiResponse.success(const ProviderListResponse(connectedOnly: false, items: [])),
    );
    when(
      () => api.listCommands(projectId: "p1", pluginId: "plugin-1"),
    ).thenAnswer((_) async => ApiResponse<CommandListResponse>.error(commandsError));

    final result = await repository.loadLegacySessionOptions(projectId: "p1", pluginId: "plugin-1");

    expect(
      result,
      isA<LegacySessionOptionsRepositoryPartial>().having(
        (value) => value.errors.map((failure) => (failure.source, failure.error)),
        "errors",
        [
          (LegacySessionOptionSource.agents, agentsError),
          (LegacySessionOptionSource.commands, commandsError),
        ],
      ),
    );
  });

  test("loadSessionOptions maps a successful aggregate", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);
    const response = SessionOptionsResponse(
      agents: Agents(agents: <AgentInfo>[]),
      providers: ProviderListResponse(items: <ProviderInfo>[], connectedOnly: false),
      commands: CommandListResponse(items: <CommandInfo>[]),
    );
    when(
      () => api.loadSessionOptions(
        projectId: "p1",
        pluginId: "plugin-1",
        mode: SessionOptionsRequestMode.dynamic,
      ),
    ).thenAnswer((_) async => ApiResponse.success(response));

    final result = await repository.loadSessionOptions(
      projectId: "p1",
      pluginId: "plugin-1",
      mode: SessionOptionsRequestMode.dynamic,
    );

    expect(
      result,
      isA<SessionOptionsRepositoryAvailable>()
          .having((value) => value.catalog.agents, "agents", response.agents.agents)
          .having((value) => value.catalog.providers, "providers", response.providers.items)
          .having((value) => value.catalog.commands, "commands", response.commands.items),
    );
  });

  test("loadSessionOptions maps an unsupported aggregate route", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);
    when(
      () => api.loadSessionOptions(
        projectId: "p1",
        pluginId: "plugin-1",
        mode: SessionOptionsRequestMode.cacheOnly,
      ),
    ).thenAnswer(
      (_) async => ApiResponse.error(
        ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null),
      ),
    );

    final result = await repository.loadSessionOptions(
      projectId: "p1",
      pluginId: "plugin-1",
      mode: SessionOptionsRequestMode.cacheOnly,
    );

    expect(result, isA<SessionOptionsRepositoryUnsupported>());
  });

  test("loadSessionOptions maps every typed code independently of HTTP status", () async {
    final cases = <(SessionOptionsErrorCode, int, Type)>[
      (SessionOptionsErrorCode.cacheUnavailable, 400, SessionOptionsRepositoryCacheUnavailable),
      (SessionOptionsErrorCode.projectNotFound, 503, SessionOptionsRepositoryProjectNotFound),
      (SessionOptionsErrorCode.refreshFailedRetained, 502, SessionOptionsRepositoryRefreshFailedRetained),
      (SessionOptionsErrorCode.refreshFailedUnavailable, 418, SessionOptionsRepositoryRefreshFailedUnavailable),
    ];

    for (final (code, status, expectedType) in cases) {
      final api = MockSessionApi();
      final repository = SessionRepository(api: api);
      when(
        () => api.loadSessionOptions(
          projectId: "p1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.nonSuccessCode(
            errorCode: status,
            rawErrorString: jsonEncode(SessionOptionsErrorResponse(code: code).toJson()),
          ),
        ),
      );

      final result = await repository.loadSessionOptions(
        projectId: "p1",
        pluginId: "plugin-1",
        mode: SessionOptionsRequestMode.forceRefresh,
      );

      expect(result.runtimeType, expectedType, reason: "failed to map $code from HTTP $status");
      expect(result, isNot(isA<SessionOptionsRepositoryFailure>()));
    }
  });

  test("normalized plugin authentication failure remains a typed refresh failure", () async {
    final api = MockSessionApi();
    final repository = SessionRepository(api: api);
    when(
      () => api.loadSessionOptions(
        projectId: "p1",
        pluginId: "plugin-1",
        mode: SessionOptionsRequestMode.forceRefresh,
      ),
    ).thenAnswer(
      (_) async => ApiResponse.error(
        ApiError.nonSuccessCode(
          errorCode: 502,
          rawErrorString: jsonEncode(
            const SessionOptionsErrorResponse(code: SessionOptionsErrorCode.refreshFailedRetained).toJson(),
          ),
        ),
      ),
    );

    final result = await repository.loadSessionOptions(
      projectId: "p1",
      pluginId: "plugin-1",
      mode: SessionOptionsRequestMode.forceRefresh,
    );

    expect(result, isA<SessionOptionsRepositoryRefreshFailedRetained>());
    expect(result, isNot(isA<NotAuthenticatedError>()));
  });

  test("unknown and malformed aggregate errors remain ordinary failures", () async {
    for (final body in <String>[
      jsonEncode(const {"code": "futureCode"}),
      "not-json",
    ]) {
      final api = MockSessionApi();
      final repository = SessionRepository(api: api);
      final error = ApiError.nonSuccessCode(errorCode: 599, rawErrorString: body);
      when(
        () => api.loadSessionOptions(
          projectId: "p1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final result = await repository.loadSessionOptions(
        projectId: "p1",
        pluginId: "plugin-1",
        mode: SessionOptionsRequestMode.dynamic,
      );

      expect(result, isA<SessionOptionsRepositoryFailure>().having((value) => value.error, "error", error));
    }
  });
}
