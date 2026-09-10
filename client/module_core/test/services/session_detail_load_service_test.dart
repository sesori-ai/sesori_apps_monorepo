import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/foundation/models/session_options/session_options_request_mode.dart";
import "package:sesori_dart_core/src/repositories/models/session_options_repository_result.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  const connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
  );

  setUpAll(registerAllFallbackValues);

  group("SessionDetailLoadService", () {
    late MockSessionRepository repository;
    late MockProjectRepository projectRepository;
    late MockPluginRepository pluginRepository;
    late MockConnectionService connectionService;
    late BehaviorSubject<ConnectionStatus> connectionStatus;
    late SessionDetailLoadService service;

    setUp(() {
      repository = MockSessionRepository();
      projectRepository = MockProjectRepository();
      pluginRepository = stubbedPluginRepository(
        plugins: const [
          PluginMetadata(
            id: "plugin-1",
            displayName: "Plugin One",
            isDefault: true,
            state: PluginLifecycleState.ready,
            actionHint: null,
            supportsPromptAttachments: true,
          ),
        ],
      );
      connectionService = MockConnectionService();
      connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
      service = SessionDetailLoadService(
        repository: repository,
        pluginRepository: pluginRepository,
        connectionService: connectionService,
      );

      when(() => connectionService.status).thenAnswer((_) => connectionStatus);
      when(() => connectionService.currentStatus).thenAnswer((_) => connectionStatus.value);
    });

    tearDown(() async {
      await connectionStatus.close();
    });

    test("load returns exactly one typed outcome without emitting ui state", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository);

      final result = await _load(service: service, projectId: "project-1");

      expect(result, isA<SessionDetailLoadResultLoaded>());
      final loaded = result as SessionDetailLoadResultLoaded;
      expect(loaded.snapshot.messages, hasLength(1));
      expect(loaded.snapshot.agents, hasLength(1));
      expect(loaded.snapshot.providerData?.items, hasLength(1));
      expect(loaded.snapshot.commands, hasLength(1));
      expect(loaded.snapshot.canonicalSessionTitle, "Canonical title");
      expect(loaded.snapshot.isArchived, isFalse);
      expect(loaded.snapshot.supportsPromptAttachments, isTrue);
      verify(() => pluginRepository.listPlugins()).called(1);
      verify(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).called(1);
      verifyNever(
        () => repository.listAgents(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      );
      verifyNever(
        () => repository.listProviders(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      );
      verifyNever(
        () => repository.listCommands(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      );
      verifyNever(() => projectRepository.findSessionContext(sessionId: any(named: "sessionId")));
    });

    test("initial load keeps the transcript available when provider authentication is required", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository);
      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).thenAnswer(
        (_) async => const SessionOptionsRepositoryAuthenticationRequired(
          actionHint: "Authenticate locally.",
        ),
      );

      final result = await _load(service: service, projectId: "project-1");

      expect(result, isA<SessionDetailLoadResultLoaded>());
      final snapshot = (result as SessionDetailLoadResultLoaded).snapshot;
      expect(snapshot.messages, hasLength(1));
      expect(snapshot.agents, isEmpty);
      expect(snapshot.providerData, isNull);
      expect(snapshot.commands, isEmpty);
    });

    test("replayed prompt defaults override parallel session metadata", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository);
      const refreshed = SessionPromptDefaults(
        agent: "build",
        model: AgentModel(providerID: "openai", modelID: "gpt-4.1", variant: "high"),
      );
      stubSessionRepositoryGetSession(
        repository: repository,
        sessionId: "session-1",
        session: testSession(
          promptDefaults: const SessionPromptDefaults(
            agent: "old-agent",
            model: AgentModel(providerID: "old-provider", modelID: "old-model", variant: "low"),
          ),
        ),
      );
      when(
        () => repository.getMessages(
          sessionId: "session-1",
          limit: any(named: "limit"),
          before: any(named: "before"),
          storedOnly: any(named: "storedOnly"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          MessageWithPartsResponse(
            messages: [_messageWithParts()],
            nextCursor: null,
            replayedPromptDefaults: refreshed,
          ),
        ),
      );

      final result = await _load(service: service, projectId: "project-1");

      expect((result as SessionDetailLoadResultLoaded).snapshot.promptDefaults, refreshed);
    });

    test("legacy fallback preserves successful options when one request fails", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository);
      final catalog = _sessionOptionsCatalog();
      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).thenAnswer(
        (_) async => const SessionOptionsRepositoryUnsupported(),
      );
      final error = ApiError.generic();
      when(
        () => repository.loadLegacySessionOptions(projectId: "project-1", pluginId: "plugin-1"),
      ).thenAnswer(
        (_) async => LegacySessionOptionsRepositoryPartial(
          catalog: SessionOptionsCatalog(
            agents: catalog.agents,
            providers: catalog.providers,
            providersConnectedOnly: catalog.providersConnectedOnly,
            commands: const <CommandInfo>[],
            lastUsedPromptDefaults: null,
          ),
          errors: [LegacySessionOptionError(source: LegacySessionOptionSource.commands, error: error)],
        ),
      );

      final result = await _load(service: service, projectId: "project-1");

      expect(result, isA<SessionDetailLoadResultLoaded>());
      final snapshot = (result as SessionDetailLoadResultLoaded).snapshot;
      expect(snapshot.agents, hasLength(1));
      expect(snapshot.providerData?.items, hasLength(1));
      expect(snapshot.commands, isEmpty);
    });

    test("the initial snapshot requests only the newest page", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository);

      await _load(service: service, projectId: "project-1");

      // A long transcript would otherwise ship in full on every open,
      // reconnect, and reload.
      verify(
        () => repository.getMessages(
          sessionId: "session-1",
          limit: SessionDetailLoadService.initialPageSize,
          before: null,
          storedOnly: false,
        ),
      ).called(1);
    });

    test("plugin discovery failure leaves attachments unresolved without failing the transcript", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository);
      when(() => pluginRepository.listPlugins()).thenAnswer(
        (_) async => ApiResponse.error(ApiError.generic()),
      );

      final result = await _load(service: service, projectId: "project-1");

      expect(result, isA<SessionDetailLoadResultLoaded>());
      expect((result as SessionDetailLoadResultLoaded).snapshot.supportsPromptAttachments, isNull);
    });

    test("load marks archived sessions in the snapshot", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository);
      stubSessionRepositoryGetSession(
        repository: repository,
        sessionId: "session-1",
        session: testSession(
          id: "session-1",
          title: "Archived",
          archivedAt: DateTime.utc(2026),
        ),
      );

      final result = await _load(service: service, projectId: "project-1");

      expect(result, isA<SessionDetailLoadResultLoaded>());
      final snapshot = (result as SessionDetailLoadResultLoaded).snapshot;
      expect(snapshot.isArchived, isTrue);
      expect(snapshot.agents, isEmpty);
      expect(snapshot.providerData, isNull);
      expect(snapshot.commands, isEmpty);
      expect(snapshot.supportsPromptAttachments, isNull);
      verifyNever(
        () => repository.loadSessionOptions(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          mode: any(named: "mode"),
        ),
      );
      verifyNever(pluginRepository.listPlugins);
    });

    test("load gives the route project id precedence over session metadata", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository);
      stubSessionRepositoryGetSession(
        repository: repository,
        sessionId: "session-1",
        session: testSession(id: "session-1", title: "Canonical title").copyWith(projectID: "other-project"),
      );

      final result = await _load(service: service, projectId: "project-1");

      expect(result, isA<SessionDetailLoadResultLoaded>());
      final loaded = result as SessionDetailLoadResultLoaded;
      expect(loaded.snapshot.commands, hasLength(1));
      verify(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).called(1);
    });

    test("initial load waits for connection readiness and then loads", () async {
      final waiting = await _load(service: service, projectId: "project-1");
      expect(waiting, isA<SessionDetailLoadResultWaitingForConnection>());

      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository);

      final loaded = await _load(service: service, projectId: "project-1");
      expect(loaded, isA<SessionDetailLoadResultLoaded>());
    });

    test("loads children before pending input", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository);
      final children = Completer<ApiResponse<SessionListResponse>>();
      when(
        () => repository.getChildren(sessionId: "session-1"),
      ).thenAnswer((_) => children.future);

      final load = _load(service: service, projectId: "project-1");
      await untilCalled(() => repository.getChildren(sessionId: "session-1"));

      verifyNever(() => repository.getPendingQuestions(sessionId: "session-1"));
      verifyNever(() => repository.getPendingPermissions(sessionId: "session-1"));
      verifyNever(() => repository.getSessionStatuses());

      children.complete(ApiResponse.success(const SessionListResponse(items: <Session>[])));
      expect(await load, isA<SessionDetailLoadResultLoaded>());
      verify(() => repository.getPendingQuestions(sessionId: "session-1")).called(1);
      verify(() => repository.getPendingPermissions(sessionId: "session-1")).called(1);
      verify(() => repository.getSessionStatuses()).called(1);
    });

    test("connected API failure does not auto-loop", () async {
      connectionStatus.add(connectedStatus);
      when(
        () => repository.getMessages(
          sessionId: "session-1",
          limit: any(named: "limit"),
          before: any(named: "before"),
          storedOnly: any(named: "storedOnly"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
      when(
        () => repository.getPendingQuestions(sessionId: "session-1"),
      ).thenAnswer((_) async => ApiResponse.success(const PendingQuestionResponse(data: <PendingQuestion>[])));
      when(
        () => repository.getPendingPermissions(sessionId: "session-1"),
      ).thenAnswer((_) async => ApiResponse.success(const PendingPermissionResponse(data: <PendingPermission>[])));
      when(
        () => repository.getChildren(sessionId: "session-1"),
      ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: <Session>[])));
      when(() => repository.getSessionStatuses()).thenAnswer(
        (_) async => ApiResponse.success(const SessionStatusResponse(statuses: <String, SessionStatus>{})),
      );
      stubSessionRepositoryGetSession(
        repository: repository,
        sessionId: "session-1",
        session: testSession(id: "session-1"),
      );
      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).thenAnswer(
        (_) async => SessionOptionsRepositoryAvailable(catalog: _sessionOptionsCatalog(), isStale: false),
      );

      final result = await _load(service: service, projectId: "project-1");

      expect(result, isA<SessionDetailLoadResultFailed>());
      verify(
        () => repository.getMessages(
          sessionId: "session-1",
          limit: any(named: "limit"),
          before: any(named: "before"),
          storedOnly: any(named: "storedOnly"),
        ),
      ).called(1);
    });

    test("load falls back to carried title state when canonical title is unavailable", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(
        repository: repository,
        canonicalSessionTitle: null,
      );

      final result = await _load(service: service, projectId: "project-1");

      expect(result, isA<SessionDetailLoadResultLoaded>());
      final loaded = result as SessionDetailLoadResultLoaded;
      expect(loaded.snapshot.canonicalSessionTitle, isNull);
    });

    test("blank route projectId scopes providers to the session's resolved project", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository);

      final result = await _load(service: service, projectId: "");

      expect(result, isA<SessionDetailLoadResultLoaded>());
      // Providers must be requested with the project resolved from the session
      // context — never the raw blank route id, which backends would normalize
      // to the bridge process CWD (the wrong project).
      verify(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      ).called(1);
      verifyNever(
        () => repository.loadSessionOptions(
          projectId: "",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.dynamic,
        ),
      );
    });

    test("a blocked load reads the store alone and carries its freshness", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository);
      when(
        () => repository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: SessionOptionsRequestMode.cacheOnly,
        ),
      ).thenAnswer((_) async => const SessionOptionsRepositoryCacheUnavailable());
      when(
        () => repository.getMessages(
          sessionId: "session-1",
          limit: any(named: "limit"),
          before: any(named: "before"),
          storedOnly: true,
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          MessageWithPartsResponse(
            messages: [_messageWithParts()],
            nextCursor: null,
            replayedPromptDefaults: null,
            awaitingHarnessSync: true,
          ),
        ),
      );

      final metadata = await service.loadMetadata(sessionId: "session-1");
      final result = await service.loadWithoutHarness(
        session: (metadata as SessionDetailMetadataFound).session,
        projectId: "project-1",
      );

      // The whole point of the blocked open: the bridge must not be asked for
      // anything that could wake the harness the user has not enabled.
      verify(
        () => repository.getMessages(
          sessionId: "session-1",
          limit: SessionDetailLoadService.initialPageSize,
          before: null,
          storedOnly: true,
        ),
      ).called(1);
      expect((result as SessionDetailLoadResultLoaded).snapshot.awaitingHarnessSync, isTrue);
    });

    test("failed metadata retains its cause and never starts plugin history", () async {
      connectionStatus.add(connectedStatus);
      final error = ApiError.generic();
      when(() => repository.getSession(sessionId: "session-1")).thenAnswer((_) async => ApiResponse.error(error));
      final result = await service.loadMetadata(sessionId: "session-1");
      expect((result as SessionDetailMetadataFailed).error, same(error));
      verifyNever(
        () => repository.getMessages(
          sessionId: any(named: "sessionId"),
          limit: any(named: "limit"),
          before: any(named: "before"),
          storedOnly: any(named: "storedOnly"),
        ),
      );
    });
  });
}

void _stubRepositorySnapshot({
  required MockSessionRepository repository,
  String? canonicalSessionTitle = "Canonical title",
}) {
  when(
    () => repository.getMessages(
      sessionId: "session-1",
      limit: any(named: "limit"),
      before: any(named: "before"),
      storedOnly: any(named: "storedOnly"),
    ),
  ).thenAnswer(
    (_) async => ApiResponse.success(
      MessageWithPartsResponse(
        messages: [_messageWithParts()],
        nextCursor: null,
        replayedPromptDefaults: null,
      ),
    ),
  );
  when(
    () => repository.getPendingQuestions(sessionId: "session-1"),
  ).thenAnswer((_) async => ApiResponse.success(const PendingQuestionResponse(data: <PendingQuestion>[])));
  when(
    () => repository.getPendingPermissions(sessionId: "session-1"),
  ).thenAnswer((_) async => ApiResponse.success(const PendingPermissionResponse(data: <PendingPermission>[])));
  when(
    () => repository.getQueuedPrompts(sessionId: "session-1"),
  ).thenAnswer((_) async => ApiResponse.success(const QueuedPromptResponse(data: <QueuedSessionPrompt>[])));
  when(
    () => repository.getChildren(sessionId: "session-1"),
  ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: <Session>[])));
  when(() => repository.getSessionStatuses()).thenAnswer(
    (_) async => ApiResponse.success(const SessionStatusResponse(statuses: <String, SessionStatus>{})),
  );
  when(
    () => repository.loadSessionOptions(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
      mode: SessionOptionsRequestMode.dynamic,
    ),
  ).thenAnswer(
    (_) async => SessionOptionsRepositoryAvailable(catalog: _sessionOptionsCatalog(), isStale: false),
  );
  stubSessionRepositoryGetSession(
    repository: repository,
    sessionId: "session-1",
    session: testSession(id: "session-1", title: canonicalSessionTitle),
  );
}

SessionOptionsCatalog _sessionOptionsCatalog() {
  return SessionOptionsCatalog(
    agents: const [
      AgentInfo(name: "build", description: "build", model: null, mode: AgentMode.primary),
    ],
    providers: const [
      ProviderInfo(
        id: "openai",
        name: "OpenAI",
        defaultModelID: "gpt-4.1",
        models: {
          "gpt-4.1": ProviderModel(
            id: "gpt-4.1",
            providerID: "openai",
            name: "GPT-4.1",
            variants: [],
            defaultVariant: null,
            family: null,
            releaseDate: null,
          ),
        },
      ),
    ],
    providersConnectedOnly: true,
    commands: const [
      CommandInfo(
        name: "review",
        template: "/review",
        hints: <String>[],
        description: "Review file",
        agent: null,
        model: null,
        provider: null,
        source: CommandSource.command,
        subtask: false,
      ),
    ],
    lastUsedPromptDefaults: null,
  );
}

MessageWithParts _messageWithParts() {
  return const MessageWithParts(
    info: Message.assistant(
      id: "msg-1",
      sessionID: "session-1",
      agent: null,
      modelID: null,
      providerID: null,
      time: null,
    ),
    parts: <MessagePart>[],
  );
}

Future<SessionDetailLoadResult> _load({required SessionDetailLoadService service, required String projectId}) async {
  return await switch (await service.loadMetadata(sessionId: "session-1")) {
    SessionDetailMetadataFound(:final session) => service.load(session: session, projectId: projectId),
    SessionDetailMetadataWaitingForConnection() => const SessionDetailLoadResult.waitingForConnection(),
    SessionDetailMetadataFailed(:final error, :final stackTrace) => SessionDetailLoadResult.failed(
      error: error,
      stackTrace: stackTrace,
    ),
  };
}
