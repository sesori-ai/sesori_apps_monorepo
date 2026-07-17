import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/send_prompt_handler.dart";
import "package:sesori_bridge/src/bridge/services/session_prompt_service.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("SendPromptHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late SessionRepository sessionRepository;
    late SendPromptHandler handler;

    setUp(() async {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      sessionRepository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      handler = SendPromptHandler(
        sessionPromptService: SessionPromptService(
          sessionRepository: sessionRepository,
        ),
      );
      for (final sessionId in ["s1", "s42", "s7", "s8", "s10", "s-update-fails", "s9"]) {
        await _insertStoredSession(
          repository: sessionRepository,
          sessionId: sessionId,
          backendSessionId: "backend-$sessionId",
          pluginId: "fake",
          agent: null,
          agentModel: null,
        );
      }
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle POST /session/prompt_async", () {
      expect(
        handler.canHandle(makeRequest("POST", "/session/prompt_async")),
        isTrue,
      );
    });

    test("does not handle GET /session/prompt_async", () {
      expect(
        handler.canHandle(makeRequest("GET", "/session/prompt_async")),
        isFalse,
      );
    });

    test("extracts session id", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s1",
          parts: [PromptPart.text(text: "Hello")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptSessionId, equals("backend-s1"));
    });

    test("parses parts", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s1",
          parts: [
            PromptPart.text(text: "Hello"),
            PromptPart.text(text: "World"),
          ],
          variant: SessionVariant(id: "low"),
          agent: null,
          model: null,
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptParts, isNotNull);
      expect(plugin.lastSendPromptParts, hasLength(2));
      expect(plugin.lastSendPromptParts![0], equals(const PluginPromptPart.text(text: "Hello")));
      expect(plugin.lastSendPromptParts![1], equals(const PluginPromptPart.text(text: "World")));
      expect(plugin.lastSendPromptVariant, equals("low"));
    });

    test("parses agent + model", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s1",
          parts: [PromptPart.text(text: "Hello")],
          variant: null,
          agent: "planner",
          model: PromptModel(providerID: "openai", modelID: "gpt-4o"),
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptAgent, equals("planner"));
      expect(plugin.lastSendPromptModel?.providerID, equals("openai"));
      expect(plugin.lastSendPromptModel?.modelID, equals("gpt-4o"));
    });

    test("successful prompt send updates stored defaults", () async {
      await _insertStoredSession(
        repository: sessionRepository,
        sessionId: "s-defaults-prompt",
        backendSessionId: "backend-s-defaults-prompt",
        pluginId: "fake",
        agent: "old-agent",
        agentModel: const AgentModel(
          providerID: "old-provider",
          modelID: "old-model",
          variant: "old-variant",
        ),
      );

      final response = await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s-defaults-prompt",
          parts: [PromptPart.text(text: "Hello")],
          variant: SessionVariant(id: "xhigh"),
          agent: "planner",
          model: PromptModel(providerID: "openai", modelID: "gpt-5"),
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, equals(const SuccessEmptyResponse()));
      expect(plugin.lastSendPromptSessionId, equals("backend-s-defaults-prompt"));
      final dbSession = await db.sessionDao.getSession(sessionId: "s-defaults-prompt");
      expect(dbSession, isNotNull);
      expect(dbSession!.lastAgent, equals("planner"));
      expect(dbSession.lastAgentModel?.providerID, equals("openai"));
      expect(dbSession.lastAgentModel?.modelID, equals("gpt-5"));
      expect(dbSession.lastAgentModel?.variant, equals("xhigh"));
    });

    test("records correct args", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s42",
          parts: [PromptPart.text(text: "Ship it")],
          variant: null,
          agent: "coder",
          model: PromptModel(
            providerID: "anthropic",
            modelID: "claude-3-5-sonnet",
          ),
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptSessionId, equals("backend-s42"));
      expect(plugin.lastSendPromptParts, hasLength(1));
      expect(plugin.lastSendPromptParts![0], equals(const PluginPromptPart.text(text: "Ship it")));
      expect(plugin.lastSendPromptAgent, equals("coder"));
      expect(plugin.lastSendPromptModel?.providerID, equals("anthropic"));
      expect(plugin.lastSendPromptModel?.modelID, equals("claude-3-5-sonnet"));
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s1",
          parts: [PromptPart.text(text: "Hello")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });

    test("does not call sendCommand when command is null", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s1",
          parts: [PromptPart.text(text: "Hello")],
          variant: null,
          agent: null,
          model: null,
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptSessionId, equals("backend-s1"));
      expect(plugin.lastSendCommandSessionId, isNull);
      expect(plugin.lastSendCommand, isNull);
    });

    test("calls sendCommand without sending prompt when command is present", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s7",
          parts: [PromptPart.text(text: "review this")],
          variant: SessionVariant(id: "xhigh"),
          agent: null,
          model: null,
          command: "review",
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptSessionId, isNull);
      expect(plugin.lastSendCommandSessionId, equals("backend-s7"));
      expect(plugin.lastSendCommand, equals("review"));
      expect(plugin.lastSendCommandArguments, equals("review this"));
      expect(plugin.lastSendCommandVariant, equals("xhigh"));
      expect(plugin.lastSendCommandAgent, isNull);
      expect(plugin.lastSendCommandModel, isNull);
    });

    test("passes empty arguments when no text part present", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s8",
          parts: [
            PromptPart.filePath(mime: "text/plain", path: "/tmp/f.txt", filename: null),
          ],
          variant: null,
          agent: null,
          model: null,
          command: "attach",
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendCommandSessionId, equals("backend-s8"));
      expect(plugin.lastSendCommand, equals("attach"));
      expect(plugin.lastSendCommandArguments, equals(""));
    });

    test("passes agent and model when command is present", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s10",
          parts: [PromptPart.text(text: "review this")],
          variant: null,
          agent: "coder",
          model: PromptModel(providerID: "openai", modelID: "gpt-5.4"),
          command: "review",
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptSessionId, isNull);
      expect(plugin.lastSendCommandSessionId, equals("backend-s10"));
      expect(plugin.lastSendCommandAgent, equals("coder"));
      expect(plugin.lastSendCommandModel, equals((providerID: "openai", modelID: "gpt-5.4")));
    });

    test("successful command send updates stored defaults", () async {
      await _insertStoredSession(
        repository: sessionRepository,
        sessionId: "s-defaults-command",
        backendSessionId: "backend-s-defaults-command",
        pluginId: "fake",
        agent: "old-agent",
        agentModel: const AgentModel(
          providerID: "old-provider",
          modelID: "old-model",
          variant: "old-variant",
        ),
      );

      final response = await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s-defaults-command",
          parts: [PromptPart.text(text: "review this")],
          variant: SessionVariant(id: "high"),
          agent: "reviewer",
          model: PromptModel(providerID: "anthropic", modelID: "claude-sonnet"),
          command: "review",
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, equals(const SuccessEmptyResponse()));
      expect(plugin.lastSendCommandSessionId, equals("backend-s-defaults-command"));
      final dbSession = await db.sessionDao.getSession(sessionId: "s-defaults-command");
      expect(dbSession, isNotNull);
      expect(dbSession!.lastAgent, equals("reviewer"));
      expect(dbSession.lastAgentModel?.providerID, equals("anthropic"));
      expect(dbSession.lastAgentModel?.modelID, equals("claude-sonnet"));
      expect(dbSession.lastAgentModel?.variant, equals("high"));
    });

    test("plugin prompt failure leaves stored defaults unchanged", () async {
      await _insertStoredSession(
        repository: sessionRepository,
        sessionId: "s-failing-prompt",
        backendSessionId: "backend-s-failing-prompt",
        pluginId: "fake",
        agent: "old-agent",
        agentModel: const AgentModel(
          providerID: "old-provider",
          modelID: "old-model",
          variant: "old-variant",
        ),
      );
      final failingPlugin = _ThrowingSendPromptPlugin();
      final localRepository = singlePluginSessionRepository(
        plugin: failingPlugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final localHandler = SendPromptHandler(
        sessionPromptService: SessionPromptService(sessionRepository: localRepository),
      );

      await expectLater(
        () => localHandler.handle(
          makeRequest("POST", "/session/prompt_async"),
          body: const SendPromptRequest(
            sessionId: "s-failing-prompt",
            parts: [PromptPart.text(text: "Hello")],
            variant: SessionVariant(id: "new-variant"),
            agent: "new-agent",
            model: PromptModel(providerID: "new-provider", modelID: "new-model"),
            command: null,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<StateError>()),
      );

      final dbSession = await db.sessionDao.getSession(sessionId: "s-failing-prompt");
      expect(dbSession, isNotNull);
      expect(dbSession!.lastAgent, equals("old-agent"));
      expect(dbSession.lastAgentModel?.providerID, equals("old-provider"));
      expect(dbSession.lastAgentModel?.modelID, equals("old-model"));
      expect(dbSession.lastAgentModel?.variant, equals("old-variant"));
      await failingPlugin.close();
    });

    test("plugin command failure leaves stored defaults unchanged", () async {
      await _insertStoredSession(
        repository: sessionRepository,
        sessionId: "s-failing-command",
        backendSessionId: "backend-s-failing-command",
        pluginId: "fake",
        agent: "old-agent",
        agentModel: const AgentModel(
          providerID: "old-provider",
          modelID: "old-model",
          variant: "old-variant",
        ),
      );
      final failingPlugin = _ThrowingSendCommandPlugin();
      final localRepository = singlePluginSessionRepository(
        plugin: failingPlugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final localHandler = SendPromptHandler(
        sessionPromptService: SessionPromptService(sessionRepository: localRepository),
      );

      await expectLater(
        () => localHandler.handle(
          makeRequest("POST", "/session/prompt_async"),
          body: const SendPromptRequest(
            sessionId: "s-failing-command",
            parts: [PromptPart.text(text: "review this")],
            variant: SessionVariant(id: "new-variant"),
            agent: "new-agent",
            model: PromptModel(providerID: "new-provider", modelID: "new-model"),
            command: "review",
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<StateError>()),
      );

      final dbSession = await db.sessionDao.getSession(sessionId: "s-failing-command");
      expect(dbSession, isNotNull);
      expect(dbSession!.lastAgent, equals("old-agent"));
      expect(dbSession.lastAgentModel?.providerID, equals("old-provider"));
      expect(dbSession.lastAgentModel?.modelID, equals("old-model"));
      expect(dbSession.lastAgentModel?.variant, equals("old-variant"));
      await failingPlugin.close();
    });

    test("prompt defaults update failure after plugin success still returns success", () async {
      final throwingRepository = _ThrowingUpdateSessionRepository(
        plugin: plugin,
        database: db,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final promptService = SessionPromptService(sessionRepository: throwingRepository);
      final changes = <SessionPromptDefaultsChange>[];
      final subscription = promptService.promptDefaultsChanges.listen(changes.add);
      addTearDown(subscription.cancel);
      addTearDown(promptService.dispose);
      final localHandler = SendPromptHandler(
        sessionPromptService: promptService,
      );

      final response = await localHandler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s-update-fails",
          parts: [PromptPart.text(text: "Hello")],
          variant: SessionVariant(id: "xhigh"),
          agent: "planner",
          model: PromptModel(providerID: "openai", modelID: "gpt-5"),
          command: null,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, equals(const SuccessEmptyResponse()));
      expect(plugin.lastSendPromptSessionId, equals("backend-s-update-fails"));
      expect(throwingRepository.updatePromptDefaultsCallCount, equals(1));
      expect(changes, isEmpty);
    });

    test("treats blank command as no command", () async {
      await handler.handle(
        makeRequest("POST", "/session/prompt_async"),
        body: const SendPromptRequest(
          sessionId: "s9",
          parts: [PromptPart.text(text: "Hello")],
          variant: null,
          agent: "coder",
          model: PromptModel(providerID: "openai", modelID: "gpt-5.4"),
          command: "   ",
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastSendPromptSessionId, equals("backend-s9"));
      expect(plugin.lastSendPromptAgent, equals("coder"));
      expect(plugin.lastSendPromptModel?.providerID, equals("openai"));
      expect(plugin.lastSendPromptVariant, isNull);
      expect(plugin.lastSendCommandSessionId, isNull);
    });

    test("throws 400 on empty session id", () async {
      expect(
        () => handler.handle(
          makeRequest("POST", "/session/prompt_async"),
          body: const SendPromptRequest(
            sessionId: "",
            parts: [PromptPart.text(text: "Hello")],
            variant: null,
            agent: null,
            model: null,
            command: null,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("missing binding returns 404 before plugin I/O", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/prompt_async",
          body: jsonEncode(
            const SendPromptRequest(
              sessionId: "missing",
              parts: [PromptPart.text(text: "Hello")],
              variant: null,
              agent: null,
              model: null,
              command: null,
            ).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, 404);
      expect(plugin.lastSendPromptSessionId, isNull);
      expect(plugin.lastSendCommandSessionId, isNull);
    });

    test("stored plugin mismatch returns 503 before plugin I/O", () async {
      await _insertStoredSession(
        repository: sessionRepository,
        sessionId: "stale-plugin-session",
        backendSessionId: "backend-stale-plugin-session",
        pluginId: "stopped-plugin",
        agent: null,
        agentModel: null,
      );

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/prompt_async",
          body: jsonEncode(
            const SendPromptRequest(
              sessionId: "stale-plugin-session",
              parts: [PromptPart.text(text: "Hello")],
              variant: null,
              agent: null,
              model: null,
              command: null,
            ).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, 503);
      expect(plugin.lastSendPromptSessionId, isNull);
      expect(plugin.lastSendCommandSessionId, isNull);
    });
  });
}

Future<void> _insertStoredSession({
  required SessionRepository repository,
  required String sessionId,
  required String backendSessionId,
  required String pluginId,
  required String? agent,
  required AgentModel? agentModel,
}) {
  return repository.insertStoredSession(
    sessionId: sessionId,
    backendSessionId: backendSessionId,
    pluginId: pluginId,
    projectId: "/repo",
    isDedicated: false,
    createdAt: 1,
    worktreePath: null,
    branchName: null,
    baseBranch: null,
    baseCommit: null,
    agent: agent,
    agentModel: agentModel,
  );
}

class _ThrowingSendPromptPlugin extends FakeBridgePlugin {
  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) {
    throw StateError("sendPrompt failed");
  }
}

class _ThrowingSendCommandPlugin extends FakeBridgePlugin {
  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) {
    throw StateError("sendCommand failed");
  }
}

class _ThrowingUpdateSessionRepository extends SessionRepository {
  int updatePromptDefaultsCallCount = 0;

  _ThrowingUpdateSessionRepository({
    required BridgePluginApi plugin,
    required AppDatabase database,
    required super.unseenCalculator,
  }) : super(
         operationalPlugins: {plugin.id: plugin},
         enabledPluginIds: [plugin.id],
         sessionDao: database.sessionDao,
         projectsDao: database.projectsDao,
         pullRequestDao: database.pullRequestDao,
         projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
         aggregateSourceDeadline: const Duration(seconds: 5),
       );

  @override
  Future<void> updatePromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
  }) {
    updatePromptDefaultsCallCount++;
    throw StateError("updatePromptDefaults failed");
  }

  @override
  Future<String> resolveProjectDirectory({required String projectId}) async => projectId;
}
