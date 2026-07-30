import "dart:convert";

import "package:sesori_bridge/src/api/database/daos/session_options_cache_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/models/session_options_cache_key.dart";
import "package:sesori_bridge/src/bridge/repositories/session_options_repository.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionOptionsRepository", () {
    late AppDatabase database;
    late SessionOptionsCacheDao cacheDao;
    late _FakePlugin plugin;
    late _RecordingPluginRuntime runtime;
    late SessionOptionsRepository repository;

    setUp(() {
      database = createTestDatabase();
      cacheDao = SessionOptionsCacheDao(database);
      plugin = _FakePlugin();
      runtime = _RecordingPluginRuntime(plugin: plugin);
      repository = SessionOptionsRepository(
        runtime: runtime,
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        cacheDao: cacheDao,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test("resolves live project paths and stable backend-session bindings", () async {
      await _insertProject(database, projectId: "project-1", path: "/projects/current");
      await database.sessionDao.insertSession(
        sessionId: "bridge-session-1",
        backendSessionId: "backend-session-1",
        projectId: "project-1",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
        pluginId: "plugin-1",
      );

      expect(await repository.resolveProjectPath(projectId: "project-1"), "/projects/current");
      expect(
        await repository.resolveProjectIdForBackendSession(
          pluginId: "plugin-1",
          backendSessionId: "backend-session-1",
        ),
        "project-1",
      );
      expect(
        await repository.resolveProjectIdForBackendSession(
          pluginId: "other-plugin",
          backendSessionId: "backend-session-1",
        ),
        isNull,
      );
    });

    test("capture keeps activation and discovery modes independent and preserves generation", () async {
      runtime
        ..active = false
        ..currentGeneration = 17;
      plugin.result = PluginSessionOptionsDiscoveryResult.observed(options: _pluginOptions(marker: "fresh"));
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );

      final result = await repository.capture(
        key: key,
        projectPath: "/projects/one",
        activation: SessionOptionsCaptureActivation.mayActivate,
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
        expectedGeneration: null,
      );

      expect(runtime.activatingCalls, 1);
      expect(runtime.activeOnlyCalls, 0);
      expect(runtime.lastOperation, SessionOptionsRuntimeOperation.capture);
      expect(plugin.callCount, 1);
      expect(plugin.lastProjectPath, "/projects/one");
      expect(plugin.lastDiscoveryMode, PluginSessionOptionsDiscoveryMode.refresh);
      expect(result, isA<SessionOptionsCaptureObserved>());
      final observed = result as SessionOptionsCaptureObserved;
      expect(observed.generation, 17);
      expect(observed.completeness, PluginSessionOptionsCompleteness.complete);
      expect(observed.response, _response(marker: "fresh"));
    });

    test("project capture rejects a path that disagrees with the cache key", () async {
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );

      await expectLater(
        repository.capture(
          key: key,
          projectPath: "/projects/other",
          activation: SessionOptionsCaptureActivation.mayActivate,
          discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
          expectedGeneration: null,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            "privacy-safe presentation",
            "Bad state: session options project path mismatch",
          ),
        ),
      );
      expect(plugin.callCount, 0);
    });

    test("active-only capture returns an explicit no-op without invoking an inactive or stale plugin", () async {
      const key = SessionOptionsCacheKey.plugin(pluginId: "plugin-1");
      runtime.active = false;

      final inactive = await repository.capture(
        key: key,
        projectPath: "/projects/one",
        activation: SessionOptionsCaptureActivation.activeOnly,
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
        expectedGeneration: null,
      );

      expect(inactive, isA<SessionOptionsCaptureInactive>());
      expect(plugin.callCount, 0);

      runtime
        ..active = true
        ..currentGeneration = 9;
      final stale = await repository.capture(
        key: key,
        projectPath: "/projects/one",
        activation: SessionOptionsCaptureActivation.activeOnly,
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
        expectedGeneration: 8,
      );

      expect(stale, isA<SessionOptionsCaptureInactive>());
      expect(plugin.callCount, 0);
      expect(runtime.activeOnlyCalls, 2);
    });

    test("plugin discovery failure remains distinct from an observed snapshot", () async {
      plugin.result = const PluginSessionOptionsDiscoveryResult.failed();

      final result = await repository.capture(
        key: const SessionOptionsCacheKey.plugin(pluginId: "plugin-1"),
        projectPath: "/projects/one",
        activation: SessionOptionsCaptureActivation.mayActivate,
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
        expectedGeneration: null,
      );

      expect(result, isA<SessionOptionsCaptureFailed>());
    });

    test("commit encodes typed JSON and read decodes the exact project-scoped row", () async {
      await _insertProject(database, projectId: "project-1", path: "/projects/one");
      const key = SessionOptionsCacheKey.project(
        pluginId: "plugin-1",
        projectId: "project-1",
        projectPath: "/projects/one",
      );
      final capturedAt = DateTime.utc(2026, 7, 30, 12);
      final candidate = SessionOptionsCacheEntry(
        key: key,
        revision: 1,
        capturedAt: capturedAt,
        completeness: PluginSessionOptionsCompleteness.complete,
        response: _response(marker: "cached"),
      );

      expect(
        await repository.commit(candidate: candidate, expectedRevision: null, generation: 1),
        isTrue,
      );

      final raw = await cacheDao.getRow(
        pluginId: "plugin-1",
        scope: PluginSessionOptionsScope.project,
        ownerId: "project-1",
      );
      expect(raw, isNotNull);
      expect(raw!.projectId, "project-1");
      expect(raw.capturedProjectPath, "/projects/one");
      expect(jsonDecodeMap(raw.agentsJson), candidate.response.agents.toJson());
      expect(jsonDecodeMap(raw.providersJson), candidate.response.providers.toJson());
      expect(jsonDecodeMap(raw.commandsJson), candidate.response.commands.toJson());

      final decoded = await repository.read(key: key);
      expect(decoded, isNotNull);
      expect(decoded!.key, key);
      expect(decoded.revision, 1);
      expect(decoded.capturedAt, capturedAt);
      expect(decoded.completeness, PluginSessionOptionsCompleteness.complete);
      expect(decoded.response, SessionOptionsResponse.fromJson(candidate.response.toJson()));
    });

    test("plugin-scoped persistence uses the plugin id as owner and no project fields", () async {
      const key = SessionOptionsCacheKey.plugin(pluginId: "plugin-1");
      final candidate = SessionOptionsCacheEntry(
        key: key,
        revision: 1,
        capturedAt: DateTime.utc(2026, 7, 30),
        completeness: PluginSessionOptionsCompleteness.partial,
        response: _response(marker: "plugin"),
      );

      await repository.commit(candidate: candidate, expectedRevision: null, generation: 1);

      final raw = await cacheDao.getRow(
        pluginId: "plugin-1",
        scope: PluginSessionOptionsScope.plugin,
        ownerId: "plugin-1",
      );
      expect(raw, isNotNull);
      expect(raw!.ownerId, "plugin-1");
      expect(raw.projectId, isNull);
      expect(raw.capturedProjectPath, isNull);
    });

    test("read wraps malformed stored JSON without hiding the original error", () async {
      await cacheDao.compareAndSet(
        row: SessionOptionsCacheTableData(
          pluginId: "plugin-1",
          scope: PluginSessionOptionsScope.plugin,
          ownerId: "plugin-1",
          projectId: null,
          capturedProjectPath: null,
          revision: 1,
          capturedAt: 1,
          completeness: PluginSessionOptionsCompleteness.complete,
          agentsJson: "not-json",
          providersJson: jsonEncode(const ProviderListResponse(items: [], connectedOnly: true).toJson()),
          commandsJson: jsonEncode(const CommandListResponse(items: []).toJson()),
        ),
        expectedRevision: null,
      );

      await expectLater(
        repository.read(key: const SessionOptionsCacheKey.plugin(pluginId: "plugin-1")),
        throwsA(
          isA<SessionOptionsCacheDecodingException>()
              .having(
                (error) => error.cause,
                "cause",
                isA<FormatException>(),
              )
              .having(
                (error) => error.toString(),
                "privacy-safe presentation",
                "SessionOptionsCacheDecodingException: invalid persisted session options cache",
              ),
        ),
      );
    });

    test("read wraps an unknown persisted completeness value", () async {
      await cacheDao.compareAndSet(
        row: SessionOptionsCacheTableData(
          pluginId: "plugin-1",
          scope: PluginSessionOptionsScope.plugin,
          ownerId: "plugin-1",
          projectId: null,
          capturedProjectPath: null,
          revision: 1,
          capturedAt: 1,
          completeness: PluginSessionOptionsCompleteness.complete,
          agentsJson: jsonEncode(const Agents(agents: []).toJson()),
          providersJson: jsonEncode(const ProviderListResponse(items: [], connectedOnly: true).toJson()),
          commandsJson: jsonEncode(const CommandListResponse(items: []).toJson()),
        ),
        expectedRevision: null,
      );
      await database.customStatement(
        "UPDATE session_options_cache_table SET completeness = 'unknown' "
        "WHERE plugin_id = 'plugin-1' AND scope = 'plugin' AND owner_id = 'plugin-1'",
      );

      await expectLater(
        repository.read(key: const SessionOptionsCacheKey.plugin(pluginId: "plugin-1")),
        throwsA(
          isA<SessionOptionsCacheDecodingException>().having(
            (error) => error.cause,
            "cause",
            isA<ArgumentError>(),
          ),
        ),
      );
    });

    test("generation fencing rejects the CAS before the DAO can write", () async {
      runtime.generationCurrent = false;
      final candidate = SessionOptionsCacheEntry(
        key: const SessionOptionsCacheKey.plugin(pluginId: "plugin-1"),
        revision: 1,
        capturedAt: DateTime.utc(2026, 7, 30),
        completeness: PluginSessionOptionsCompleteness.complete,
        response: _response(marker: "stale"),
      );

      await expectLater(
        repository.commit(candidate: candidate, expectedRevision: null, generation: 1),
        throwsA(isA<PluginOperationException>()),
      );

      expect(runtime.commitCalls, 1);
      expect(runtime.lastOperation, SessionOptionsRuntimeOperation.commit);
      expect(
        await cacheDao.getRow(
          pluginId: "plugin-1",
          scope: PluginSessionOptionsScope.plugin,
          ownerId: "plugin-1",
        ),
        isNull,
      );
    });
  });
}

Future<void> _insertProject(AppDatabase database, {required String projectId, required String path}) {
  return database.projectsDao.recordOpenedProject(
    projectId: projectId,
    path: path,
    displayName: null,
    createdAt: 1,
    updatedAt: 1,
  );
}

PluginSessionOptions _pluginOptions({required String marker}) {
  return PluginSessionOptions(
    agents: [
      PluginAgent(
        name: "agent-$marker",
        description: "description-$marker",
        model: const PluginAgentModel(modelID: "model-1", providerID: "provider-1", variant: "high"),
        mode: PluginAgentMode.primary,
        hidden: false,
      ),
    ],
    providers: PluginProvidersResult(
      providers: [
        PluginProvider.custom(
          id: "provider-1",
          name: "Provider $marker",
          authType: PluginProviderAuthType.unknown,
          models: [
            PluginModel(
              id: "model-1",
              name: "Model $marker",
              variants: const ["high"],
              family: "family-$marker",
              releaseDate: DateTime.utc(2026, 1, 2),
            ),
          ],
          defaultModelID: "model-1",
        ),
      ],
    ),
    commands: [
      PluginCommand(
        name: "command-$marker",
        template: "private prompt text",
        hints: const ["hint"],
        description: "description-$marker",
        provider: "provider-1",
        source: PluginCommandSource.skill,
      ),
    ],
    completeness: PluginSessionOptionsCompleteness.complete,
  );
}

SessionOptionsResponse _response({required String marker}) {
  return SessionOptionsResponse(
    agents: Agents(
      agents: [
        AgentInfo(
          name: "agent-$marker",
          description: "description-$marker",
          model: const AgentModel(modelID: "model-1", providerID: "provider-1", variant: "high"),
          mode: AgentMode.primary,
        ),
      ],
    ),
    providers: ProviderListResponse(
      items: [
        ProviderInfo(
          id: "provider-1",
          name: "Provider $marker",
          models: {
            "model-1": ProviderModel(
              id: "model-1",
              providerID: "provider-1",
              name: "Model $marker",
              variants: const ["high"],
              family: "family-$marker",
              releaseDate: DateTime.utc(2026, 1, 2),
            ),
          },
          defaultModelID: "model-1",
        ),
      ],
      connectedOnly: true,
    ),
    commands: CommandListResponse(
      items: [
        CommandInfo(
          name: "command-$marker",
          template: null,
          hints: const ["hint"],
          description: "description-$marker",
          agent: null,
          model: null,
          provider: "provider-1",
          source: CommandSource.skill,
          subtask: null,
        ),
      ],
    ),
  );
}

class _FakePlugin implements BridgeDerivedProjectsPluginApi {
  PluginSessionOptionsDiscoveryResult result = PluginSessionOptionsDiscoveryResult.observed(
    options: _pluginOptions(marker: "default"),
  );
  int callCount = 0;
  String? lastProjectPath;
  PluginSessionOptionsDiscoveryMode? lastDiscoveryMode;

  @override
  String get id => "plugin-1";

  @override
  Stream<BridgeSseEvent> get events => const Stream.empty();

  @override
  String get launchDirectory => "/projects";

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async {
    callCount++;
    lastProjectPath = projectId;
    lastDiscoveryMode = discoveryMode;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingPluginRuntime implements PluginRuntime {
  _RecordingPluginRuntime({required this.plugin});

  final BridgePluginApi plugin;
  bool active = true;
  bool generationCurrent = true;
  int currentGeneration = 1;
  int activatingCalls = 0;
  int activeOnlyCalls = 0;
  int commitCalls = 0;
  Enum? lastOperation;

  @override
  Set<String> get activePluginIds => active ? {plugin.id} : const {};

  @override
  bool isCurrentGeneration({required String pluginId, required int generation}) {
    return generationCurrent && pluginId == plugin.id && generation == currentGeneration;
  }

  @override
  Future<({T value, int generation})> useWithGeneration<T>({
    required String pluginId,
    required Enum operation,
    required Future<T> Function(BridgePluginApi api) body,
  }) async {
    activatingCalls++;
    lastOperation = operation;
    final value = await body(plugin);
    return (value: value, generation: currentGeneration);
  }

  @override
  Future<T?> useIfActive<T>({
    required String pluginId,
    required Enum operation,
    required Future<T> Function(BridgePluginApi api, int generation) body,
  }) async {
    activeOnlyCalls++;
    lastOperation = operation;
    if (!active) return null;
    return body(plugin, currentGeneration);
  }

  @override
  Future<R> commitCurrentGeneration<R>({
    required String pluginId,
    required int generation,
    required Enum operation,
    required Future<R> Function() commit,
  }) async {
    commitCalls++;
    lastOperation = operation;
    if (!isCurrentGeneration(pluginId: pluginId, generation: generation)) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "stale generation");
    }
    return commit();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
