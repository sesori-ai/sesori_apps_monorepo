import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  const connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
    health: HealthResponse(healthy: true, version: "0.1.200"),
  );

  setUpAll(registerAllFallbackValues);

  group("SessionDetailLoadService", () {
    late MockSessionRepository repository;
    late MockProjectRepository projectRepository;
    late MockConnectionService connectionService;
    late BehaviorSubject<ConnectionStatus> connectionStatus;
    late SessionDetailLoadService service;

    setUp(() {
      repository = MockSessionRepository();
      projectRepository = MockProjectRepository();
      connectionService = MockConnectionService();
      connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
      service = SessionDetailLoadService(
        repository: repository,
        projectRepository: projectRepository,
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
      _stubRepositorySnapshot(repository: repository, projectRepository: projectRepository);

      final result = await service.load(sessionId: "session-1");

      expect(result, isA<SessionDetailLoadResultLoaded>());
      final loaded = result as SessionDetailLoadResultLoaded;
      expect(loaded.isBridgeConnected, isTrue);
      expect(loaded.snapshot.messages, hasLength(1));
      expect(loaded.snapshot.commands, hasLength(1));
      expect(loaded.snapshot.canonicalSessionTitle, "Canonical title");
    });

    test("load uses route projectId to fetch commands when context lookup fails", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository, projectRepository: projectRepository);
      when(() => projectRepository.findSessionContext(sessionId: "session-1")).thenThrow(Exception("lookup failed"));

      final result = await service.load(sessionId: "session-1", projectId: "project-1");

      expect(result, isA<SessionDetailLoadResultLoaded>());
      final loaded = result as SessionDetailLoadResultLoaded;
      expect(loaded.snapshot.commands, hasLength(1));
      verify(() => repository.listCommands(projectId: "project-1")).called(1);
    });

    test("initial load waits for connection readiness and then loads", () async {
      final waiting = await service.load(sessionId: "session-1");
      expect(waiting, isA<SessionDetailLoadResultWaitingForConnection>());

      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository, projectRepository: projectRepository);

      final loaded = await service.load(sessionId: "session-1");
      expect(loaded, isA<SessionDetailLoadResultLoaded>());
    });

    test("connected API failure does not auto-loop", () async {
      connectionStatus.add(connectedStatus);
      when(
        () => repository.getMessages(sessionId: "session-1"),
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
      when(
        () => repository.listAgents(),
      ).thenAnswer((_) async => ApiResponse.success(const Agents(agents: <AgentInfo>[])));
      when(() => repository.listProviders()).thenAnswer(
        (_) async => ApiResponse.success(const ProviderListResponse(connectedOnly: false, items: <ProviderInfo>[])),
      );
      when(() => projectRepository.findSessionContext(sessionId: "session-1")).thenAnswer(
        (_) async => const ProjectSessionContext(projectId: "project-1", sessionTitle: "Canonical title"),
      );
      when(() => repository.listCommands(projectId: "project-1")).thenAnswer(
        (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
      );

      final result = await service.load(sessionId: "session-1");

      expect(result, isA<SessionDetailLoadResultFailed>());
      verify(() => repository.getMessages(sessionId: "session-1")).called(1);
    });

    test("load falls back to carried title state when canonical title is unavailable", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(
        repository: repository,
        projectRepository: projectRepository,
        canonicalSessionTitle: null,
      );

      final result = await service.load(sessionId: "session-1");

      expect(result, isA<SessionDetailLoadResultLoaded>());
      final loaded = result as SessionDetailLoadResultLoaded;
      expect(loaded.snapshot.canonicalSessionTitle, isNull);
    });

    test("project session context lookup failure is non-fatal when required reads succeed", () async {
      connectionStatus.add(connectedStatus);
      _stubRepositorySnapshot(repository: repository, projectRepository: projectRepository);
      when(() => projectRepository.findSessionContext(sessionId: "session-1")).thenThrow(Exception("lookup failed"));

      final result = await service.load(sessionId: "session-1");

      expect(result, isA<SessionDetailLoadResultLoaded>());
      final loaded = result as SessionDetailLoadResultLoaded;
      expect(loaded.snapshot.messages, hasLength(1));
      expect(loaded.snapshot.canonicalSessionTitle, isNull);
    });
  });
}

void _stubRepositorySnapshot({
  required MockSessionRepository repository,
  required MockProjectRepository projectRepository,
  String? canonicalSessionTitle = "Canonical title",
}) {
  when(
    () => repository.getMessages(sessionId: "session-1"),
  ).thenAnswer((_) async => ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()])));
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
  when(() => repository.listAgents()).thenAnswer(
    (_) async => ApiResponse.success(
      const Agents(
        agents: [
          AgentInfo(name: "build", description: "build", model: null, variant: null, mode: AgentMode.primary),
        ],
      ),
    ),
  );
  when(() => repository.listProviders()).thenAnswer(
    (_) async => ApiResponse.success(
      const ProviderListResponse(
        connectedOnly: false,
        items: [
          ProviderInfo(
            id: "openai",
            name: "OpenAI",
            defaultModelID: "gpt-4.1",
            models: {
              "gpt-4.1": ProviderModel(
                id: "gpt-4.1",
                providerID: "openai",
                name: "GPT-4.1",
                family: null,
                releaseDate: null,
              ),
            },
          ),
        ],
      ),
    ),
  );
  when(() => repository.listCommands(projectId: "project-1")).thenAnswer(
    (_) async => ApiResponse.success(
      const CommandListResponse(
        items: <CommandInfo>[
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
      ),
    ),
  );
  when(() => projectRepository.findSessionContext(sessionId: "session-1")).thenAnswer(
    (_) async => ProjectSessionContext(projectId: "project-1", sessionTitle: canonicalSessionTitle),
  );
}

MessageWithParts _messageWithParts() {
  return const MessageWithParts(
    info: Message(id: "msg-1", role: "assistant", sessionID: "session-1", agent: null, modelID: null, providerID: null),
    parts: <MessagePart>[],
  );
}
