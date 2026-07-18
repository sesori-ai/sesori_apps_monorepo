import "dart:convert";
import "dart:ffi" show Abi;
import "dart:io";
import "dart:math" show min;

import "package:args/args.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/projects_table.dart";
import "package:sesori_bridge/src/api/database/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

const _defaultWarmupCount = 25;
const _defaultSampleCount = 2000;
const _defaultPluginCount = 1;
const _defaultProjectCount = 500;
const _defaultSessionCount = 10000;
const _defaultUnpaginatedSessionCount = 1000;
const _defaultTimestamp = 1700000000000;
const _projectDirectory = "/benchmark/project-0000";
const _smallProjectDirectory = "/benchmark/project-0001";
const _childSessionId = "child-00000";

Future<void> main(List<String> arguments) async {
  try {
    final configuration = _BenchmarkConfiguration.parse(arguments: arguments);
    final report = await _LiveListBenchmark(configuration: configuration).run();
    stdout.writeln(const JsonEncoder.withIndent("  ").convert(report));
  } on Object catch (error, stackTrace) {
    stderr.writeln("live-list benchmark failed: $error");
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

class _BenchmarkConfiguration {
  const _BenchmarkConfiguration({
    required this.warmupCount,
    required this.sampleCount,
    required this.pluginCount,
    required this.projectCount,
    required this.sessionCount,
    required this.unpaginatedSessionCount,
  });

  final int warmupCount;
  final int sampleCount;
  final int pluginCount;
  final int projectCount;
  final int sessionCount;
  final int unpaginatedSessionCount;

  static _BenchmarkConfiguration parse({required List<String> arguments}) {
    final parser = ArgParser()
      ..addOption("warmup", defaultsTo: "$_defaultWarmupCount")
      ..addOption("samples", defaultsTo: "$_defaultSampleCount")
      ..addOption("plugins", defaultsTo: "$_defaultPluginCount")
      ..addOption("projects", defaultsTo: "$_defaultProjectCount")
      ..addOption("sessions", defaultsTo: "$_defaultSessionCount")
      ..addOption("unpaginated-sessions", defaultsTo: "$_defaultUnpaginatedSessionCount");
    final parsed = parser.parse(arguments);
    final warmupCount = int.tryParse(parsed.option("warmup") ?? "");
    final sampleCount = int.tryParse(parsed.option("samples") ?? "");
    final pluginCount = int.tryParse(parsed.option("plugins") ?? "");
    final projectCount = int.tryParse(parsed.option("projects") ?? "");
    final sessionCount = int.tryParse(parsed.option("sessions") ?? "");
    final unpaginatedSessionCount = int.tryParse(parsed.option("unpaginated-sessions") ?? "");
    if (warmupCount == null || warmupCount < 0) {
      throw const FormatException("--warmup must be a non-negative integer");
    }
    if (sampleCount == null || sampleCount < 1) {
      throw const FormatException("--samples must be a positive integer");
    }
    if (pluginCount == null || !const {1, 3, 8}.contains(pluginCount)) {
      throw const FormatException("--plugins must be 1, 3, or 8");
    }
    if (projectCount == null || projectCount < 1) {
      throw const FormatException("--projects must be a positive integer");
    }
    if (sessionCount == null || sessionCount < 1) {
      throw const FormatException("--sessions must be a positive integer");
    }
    if (unpaginatedSessionCount == null || unpaginatedSessionCount < 1) {
      throw const FormatException("--unpaginated-sessions must be a positive integer");
    }
    return _BenchmarkConfiguration(
      warmupCount: warmupCount,
      sampleCount: sampleCount,
      pluginCount: pluginCount,
      projectCount: projectCount,
      sessionCount: sessionCount,
      unpaginatedSessionCount: unpaginatedSessionCount,
    );
  }
}

class _LiveListBenchmark {
  const _LiveListBenchmark({required _BenchmarkConfiguration configuration}) : _configuration = configuration;

  final _BenchmarkConfiguration _configuration;

  Future<Map<String, Object?>> run() async {
    final rssBefore = ProcessInfo.currentRss;
    final temporaryDirectory = await Directory.systemTemp.createTemp("sesori-live-list-baseline-");
    final databaseFile = File(p.join(temporaryDirectory.path, "benchmark.sqlite"));
    AppDatabase? database;

    try {
      database = AppDatabase.openFile(file: databaseFile);
      final sqliteVersion = await _sqliteVersion(database: database);
      final journalMode = await _journalMode(database: database);
      if (journalMode.toLowerCase() != "wal") {
        throw StateError("benchmark database uses $journalMode journaling; expected WAL");
      }
      final scenarios = await _runScenarios(database: database);
      final queryPlans = await _queryPlans(database: database);
      final rssAfter = ProcessInfo.currentRss;
      final databaseSchemaVersion = database.schemaVersion;
      await database.close();
      database = null;
      final databaseBytes = databaseFile.lengthSync();

      return {
        "schemaVersion": 1,
        "benchmark": "live_list_baseline",
        "generatedAt": DateTime.now().toUtc().toIso8601String(),
        "host": _hostMetadata(),
        "runtime": _runtimeMetadata(),
        "commit": _commitMetadata(),
        "database": {
          "engine": "sqlite",
          "engineVersion": sqliteVersion,
          "journalMode": journalMode,
          "driftSchemaVersion": databaseSchemaVersion,
          "fileBacked": true,
          "temporary": true,
          "bytes": databaseBytes,
          "queryPlans": queryPlans,
        },
        "fixture": {
          "pluginCount": _configuration.pluginCount,
          "projectCount": _configuration.projectCount,
          "sessionCount": _configuration.sessionCount,
          "unpaginatedSessionCount": _configuration.unpaginatedSessionCount,
        },
        "measurement": {
          "warmupCount": _configuration.warmupCount,
          "sampleCount": _configuration.sampleCount,
          "clock": "Stopwatch",
          "unit": "microseconds",
          "percentileMethod": "nearest-rank",
        },
        "rssBytes": {
          "before": rssBefore,
          "after": rssAfter,
          "delta": rssAfter - rssBefore,
        },
        "scenarios": scenarios,
      };
    } finally {
      if (database != null) {
        await database.close();
      }
      try {
        await temporaryDirectory.delete(recursive: true);
      } on FileSystemException catch (error, stackTrace) {
        stderr.writeln("could not delete benchmark directory ${temporaryDirectory.path}: $error");
        stderr.writeln(stackTrace);
      }
    }
  }

  Future<List<Map<String, Object?>>> _runScenarios({required AppDatabase database}) async {
    final plugins = [
      for (var index = 0; index < _configuration.pluginCount; index++)
        _ThrowingBenchmarkPlugin(id: "catalog-benchmark-$index"),
    ];
    final pluginCounters = _PluginCounterAggregate(plugins: plugins);
    final operationalPlugins = <String, BridgePluginApi>{
      for (final plugin in plugins) plugin.id: plugin,
    };
    await _seedProjects(database: database, projectCount: _configuration.projectCount);
    final filesystemApi = _ExistingFilesystemApi();
    const unseenCalculator = SessionUnseenCalculator();
    // Never invoked by the benchmarked listing paths; wired only to satisfy
    // the repository constructor.
    final gitCliApi = GitCliApi(processRunner: ProcessRunner(), gitPathExists: ({required String gitPath}) => false);

    final projectRepository = ProjectRepository(
      gitCliApi: gitCliApi,
      operationalPlugins: operationalPlugins,
      defaultEnabledPluginId: plugins.first.id,
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      unseenCalculator: unseenCalculator,
      filesystemApi: filesystemApi,
      projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
      aggregateSourceDeadline: const Duration(seconds: 5),
    );
    final results = <Map<String, Object?>>[];
    results.add(
      await _measure(
        name: "catalog_${_configuration.projectCount}_projects",
        fixture: {
          "source": "catalog",
          "readPath": "projects",
          "projectCount": _configuration.projectCount,
        },
        expectedRowsReturned: _configuration.projectCount,
        pluginCounters: pluginCounters,
        operation: () async {
          final projects = await projectRepository.getProjects();
          _verifyBoundaries(
            name: "project catalog",
            expectedFirst: _projectId(index: _configuration.projectCount - 1),
            expectedLast: _projectDirectory,
            actualFirst: projects.firstOrNull?.id,
            actualLast: projects.lastOrNull?.id,
          );
          return projects.length;
        },
      ),
    );
    await _seedSessions(
      database: database,
      pluginIds: plugins.map((plugin) => plugin.id).toList(growable: false),
      sessionCount: _configuration.sessionCount,
      unpaginatedSessionCount: _configuration.unpaginatedSessionCount,
    );

    final sessionRepository = _sessionRepository(database: database, plugins: operationalPlugins);
    final mutationDispatcher = SessionMutationDispatcher(sessionRepository: sessionRepository);
    final pageSize = min(100, _configuration.sessionCount);

    try {
      results.add(
        await _measure(
          name: "catalog_${pageSize}_of_${_configuration.sessionCount}_endpoint_core_without_pr_refresh",
          fixture: {
            "source": "catalog",
            "readPath": "roots",
            "measuredPath": "endpoint-core-without-pr-refresh",
            "sessionCount": _configuration.sessionCount,
            "start": 0,
            "limit": pageSize,
          },
          expectedRowsReturned: pageSize,
          pluginCounters: pluginCounters,
          operation: () => _sessionEndpointCoreCount(
            repository: sessionRepository,
            mutationDispatcher: mutationDispatcher,
            projectId: _projectDirectory,
            start: 0,
            limit: pageSize,
            expectedFirstSessionId: _sessionId(prefix: "large", index: _configuration.sessionCount - 1),
            expectedLastSessionId: _sessionId(
              prefix: "large",
              index: _configuration.sessionCount - pageSize,
            ),
          ),
        ),
      );
      results.add(
        await _measure(
          name: "catalog_${_configuration.unpaginatedSessionCount}_unpaginated_endpoint_core_without_pr_refresh",
          fixture: {
            "source": "catalog",
            "readPath": "roots",
            "measuredPath": "endpoint-core-without-pr-refresh",
            "sessionCount": _configuration.unpaginatedSessionCount,
            "start": null,
            "limit": null,
          },
          expectedRowsReturned: _configuration.unpaginatedSessionCount,
          pluginCounters: pluginCounters,
          operation: () => _sessionEndpointCoreCount(
            repository: sessionRepository,
            mutationDispatcher: mutationDispatcher,
            projectId: _smallProjectDirectory,
            start: null,
            limit: null,
            expectedFirstSessionId: _sessionId(
              prefix: "small",
              index: _configuration.unpaginatedSessionCount - 1,
            ),
            expectedLastSessionId: _sessionId(prefix: "small", index: 0),
          ),
        ),
      );
      final detailSessionId = _sessionId(prefix: "large", index: _configuration.sessionCount - 1);
      results.add(
        await _measure(
          name: "catalog_session_detail",
          fixture: {
            "source": "catalog",
            "readPath": "detail",
            "projectId": _projectDirectory,
            "sessionId": detailSessionId,
          },
          expectedRowsReturned: 1,
          pluginCounters: pluginCounters,
          operation: () async {
            final projectId = await sessionRepository.findProjectIdForSession(sessionId: detailSessionId);
            if (projectId != _projectDirectory) {
              throw StateError("session detail resolved project $projectId; expected $_projectDirectory");
            }
            final session = await sessionRepository.getSessionForProject(
              projectId: _projectDirectory,
              sessionId: detailSessionId,
            );
            if (session?.id != detailSessionId) {
              throw StateError("session detail returned ${session?.id}; expected $detailSessionId");
            }
            return 1;
          },
        ),
      );
      results.add(
        await _measure(
          name: "catalog_child_sessions",
          fixture: const {
            "source": "catalog",
            "readPath": "children",
            "parentSessionId": "large-00000",
          },
          expectedRowsReturned: 1,
          pluginCounters: pluginCounters,
          operation: () async {
            final sessions = await sessionRepository.getChildSessions(
              sessionId: _sessionId(prefix: "large", index: 0),
            );
            if (sessions.length != 1 || sessions.single.id != _childSessionId) {
              throw StateError(
                "child list returned ${sessions.map((session) => session.id).toList()}; "
                "expected [$_childSessionId]",
              );
            }
            return sessions.length;
          },
        ),
      );
      return results;
    } finally {
      await mutationDispatcher.dispose();
      await sessionRepository.dispose();
    }
  }

  Future<void> _seedProjects({required AppDatabase database, required int projectCount}) async {
    final rows = [
      for (var index = 0; index < projectCount; index++)
        ProjectDto(
          projectId: _projectId(index: index),
          path: _projectId(index: index),
          hidden: false,
          baseBranch: null,
          displayName: "project-${index.toString().padLeft(4, "0")}",
          createdAt: _defaultTimestamp + index,
          updatedAt: _defaultTimestamp + index,
          projectionUpdatedAt: _defaultTimestamp + index,
        ),
    ];
    if (projectCount == 1) {
      rows.add(
        const ProjectDto(
          projectId: _smallProjectDirectory,
          path: _smallProjectDirectory,
          hidden: true,
          baseBranch: null,
          displayName: "project-0001",
          createdAt: _defaultTimestamp + 1,
          updatedAt: _defaultTimestamp + 1,
          projectionUpdatedAt: _defaultTimestamp + 1,
        ),
      );
    }
    await database.projectsDao.upsertProjectRows(
      rows: rows,
    );
  }

  Future<void> _seedSessions({
    required AppDatabase database,
    required List<String> pluginIds,
    required int sessionCount,
    required int unpaginatedSessionCount,
  }) async {
    await database.sessionDao.upsertSessionRows(
      rows: [
        ..._sessions(
          count: sessionCount,
          projectId: _projectDirectory,
          idPrefix: "large",
          pluginIds: pluginIds,
        ),
        ..._sessions(
          count: unpaginatedSessionCount,
          projectId: _smallProjectDirectory,
          idPrefix: "small",
          pluginIds: pluginIds,
        ),
        SessionDto(
          sessionId: _childSessionId,
          backendSessionId: "child-backend-00000",
          projectId: _projectDirectory,
          parentSessionId: _sessionId(prefix: "large", index: 0),
          directory: _projectDirectory,
          worktreePath: null,
          branchName: null,
          isDedicated: false,
          archivedAt: null,
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
          createdAt: _defaultTimestamp + sessionCount,
          updatedAt: _defaultTimestamp + sessionCount,
          projectionUpdatedAt: _defaultTimestamp + sessionCount,
          lastActivityAt: null,
          lastSeenAt: null,
          lastUserMessageAt: null,
          pluginId: pluginIds.first,
          title: null,
          catalogTitle: "Child session",
        ),
      ],
    );
  }

  SessionRepository _sessionRepository({
    required AppDatabase database,
    required Map<String, BridgePluginApi> plugins,
  }) {
    return SessionRepository(
      operationalPlugins: plugins,
      bridgeDerivedProjectPluginIds: {
        for (final entry in plugins.entries)
          if (entry.value is BridgeDerivedProjectsPluginApi) entry.key,
      },
      enabledPluginIds: plugins.keys.toList(growable: false),
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      pullRequestDao: database.pullRequestDao,
      unseenCalculator: const SessionUnseenCalculator(),
      projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
      aggregateSourceDeadline: const Duration(seconds: 5),
    );
  }

  Future<int> _sessionEndpointCoreCount({
    required SessionRepository repository,
    required SessionMutationDispatcher mutationDispatcher,
    required String projectId,
    required int? start,
    required int? limit,
    required String expectedFirstSessionId,
    required String expectedLastSessionId,
  }) async {
    var sessions = await repository.getSessionsForProject(
      projectId: projectId,
      start: start,
      limit: limit,
    );
    for (final session in sessions) {
      await mutationDispatcher.applyPendingTitle(sessionId: session.id);
    }
    sessions = await repository.enrichSessions(sessions: sessions);
    _verifyBoundaries(
      name: "session catalog for $projectId",
      expectedFirst: expectedFirstSessionId,
      expectedLast: expectedLastSessionId,
      actualFirst: sessions.firstOrNull?.id,
      actualLast: sessions.lastOrNull?.id,
    );
    return sessions.length;
  }

  Future<Map<String, Object?>> _measure({
    required String name,
    required Map<String, Object?> fixture,
    required int expectedRowsReturned,
    required _PluginCounterAggregate pluginCounters,
    required Future<int> Function() operation,
  }) async {
    for (var index = 0; index < _configuration.warmupCount; index++) {
      final rows = await operation();
      _verifyRows(name: name, expected: expectedRowsReturned, actual: rows);
    }
    pluginCounters.resetCounters();

    final samples = <int>[];
    var rowsReturned = 0;
    for (var index = 0; index < _configuration.sampleCount; index++) {
      final stopwatch = Stopwatch()..start();
      final rows = await operation();
      stopwatch.stop();
      _verifyRows(name: name, expected: expectedRowsReturned, actual: rows);
      rowsReturned += rows;
      samples.add(stopwatch.elapsedMicroseconds);
    }
    if (pluginCounters.calls != 0) {
      throw StateError(
        "$name made ${pluginCounters.calls} aggregate plugin calls across "
        "${pluginCounters.pluginCount} plugins; expected zero",
      );
    }
    samples.sort();

    return {
      "name": name,
      "fixture": fixture,
      "warmupCount": _configuration.warmupCount,
      "sampleCount": _configuration.sampleCount,
      "latencyMicroseconds": {
        "p50": _nearestRank(sortedSamples: samples, percentile: 0.50),
        "p95": _nearestRank(sortedSamples: samples, percentile: 0.95),
        "p99": _nearestRank(sortedSamples: samples, percentile: 0.99),
        "max": samples.last,
      },
      "totals": {
        "pluginCalls": pluginCounters.calls,
        "pluginRowsEnumerated": pluginCounters.rowsEnumerated,
        "rowsReturned": rowsReturned,
      },
      "perSample": {
        "pluginCalls": pluginCounters.calls / _configuration.sampleCount,
        "pluginRowsEnumerated": pluginCounters.rowsEnumerated / _configuration.sampleCount,
        "rowsReturned": rowsReturned / _configuration.sampleCount,
      },
    };
  }

  void _verifyRows({required String name, required int expected, required int actual}) {
    if (actual != expected) {
      throw StateError("$name returned $actual rows; expected $expected");
    }
  }

  void _verifyBoundaries({
    required String name,
    required String expectedFirst,
    required String expectedLast,
    required String? actualFirst,
    required String? actualLast,
  }) {
    if (actualFirst != expectedFirst || actualLast != expectedLast) {
      throw StateError(
        "$name returned boundaries [$actualFirst, $actualLast]; "
        "expected [$expectedFirst, $expectedLast]",
      );
    }
  }

  int _nearestRank({required List<int> sortedSamples, required double percentile}) {
    final rank = (percentile * sortedSamples.length).ceil();
    return sortedSamples[rank - 1];
  }

  List<SessionDto> _sessions({
    required int count,
    required String projectId,
    required String idPrefix,
    required List<String> pluginIds,
  }) {
    return List<SessionDto>.generate(
      count,
      (index) => SessionDto(
        sessionId: _sessionId(prefix: idPrefix, index: index),
        backendSessionId: "$idPrefix-backend-${index.toString().padLeft(5, "0")}",
        projectId: projectId,
        parentSessionId: null,
        directory: projectId,
        worktreePath: null,
        branchName: null,
        isDedicated: false,
        archivedAt: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
        createdAt: _defaultTimestamp + index,
        updatedAt: _defaultTimestamp + index,
        projectionUpdatedAt: _defaultTimestamp + index,
        lastActivityAt: null,
        lastSeenAt: null,
        lastUserMessageAt: null,
        pluginId: pluginIds[index % pluginIds.length],
        title: null,
        catalogTitle: "Session $index",
      ),
      growable: false,
    );
  }

  Future<String> _sqliteVersion({required AppDatabase database}) async {
    final row = await database.customSelect("SELECT sqlite_version() AS version").getSingle();
    return row.read<String>("version");
  }

  Future<String> _journalMode({required AppDatabase database}) async {
    final row = await database.customSelect("PRAGMA journal_mode").getSingle();
    return row.read<String>("journal_mode");
  }

  Future<Map<String, Object?>> _queryPlans({required AppDatabase database}) async {
    const visibleProjectsSql =
        "SELECT * FROM projects_table WHERE hidden = 0 "
        "ORDER BY updated_at DESC, project_id DESC";
    const rootPaginationSql =
        "SELECT * FROM sessions_table WHERE project_id = '/benchmark/project-0000' "
        "AND parent_session_id IS NULL ORDER BY updated_at DESC, session_id DESC "
        "LIMIT 100 OFFSET 25";

    Future<Map<String, Object?>> explain({
      required String sql,
      required String expectedIndex,
    }) async {
      final rows = await database.customSelect("EXPLAIN QUERY PLAN $sql").get();
      final details = rows.map((row) => row.read<String>("detail")).toList(growable: false);
      if (!details.any((detail) => detail.contains(expectedIndex))) {
        throw StateError("Query plan does not use $expectedIndex: $details");
      }
      if (details.any((detail) => detail.contains("USE TEMP B-TREE"))) {
        throw StateError("Query plan uses temporary sorting: $details");
      }
      return {
        "sql": sql,
        "details": details,
      };
    }

    return {
      "visibleProjectOrdering": await explain(
        sql: visibleProjectsSql,
        expectedIndex: "idx_projects_updated",
      ),
      "rootPagination": await explain(
        sql: rootPaginationSql,
        expectedIndex: "idx_sessions_roots",
      ),
    };
  }

  Map<String, Object?> _hostMetadata() {
    return {
      "operatingSystem": Platform.operatingSystem,
      "operatingSystemVersion": Platform.operatingSystemVersion,
      "architecture": Abi.current().toString(),
      "logicalProcessors": Platform.numberOfProcessors,
      "cpuModel": _cpuModel(),
    };
  }

  Map<String, Object?> _runtimeMetadata() {
    return {
      "dartVersion": Platform.version,
      "productMode": const bool.fromEnvironment("dart.vm.product"),
    };
  }

  Map<String, Object?> _commitMetadata() {
    final sha = _gitOutput(arguments: const ["rev-parse", "HEAD"]);
    final branch = _gitOutput(arguments: const ["rev-parse", "--abbrev-ref", "HEAD"]);
    final status = _gitOutput(arguments: const ["status", "--porcelain"]);
    return {
      "sha": sha,
      "branch": branch,
      "dirty": status?.isNotEmpty,
    };
  }

  String? _gitOutput({required List<String> arguments}) {
    try {
      final result = Process.runSync("git", arguments);
      if (result.exitCode != 0) {
        stderr.writeln("git ${arguments.join(" ")} failed with exit code ${result.exitCode}: ${result.stderr}");
        return null;
      }
      return (result.stdout as String).trim();
    } on ProcessException catch (error, stackTrace) {
      stderr.writeln("git ${arguments.join(" ")} failed: $error");
      stderr.writeln(stackTrace);
      return null;
    }
  }

  String? _cpuModel() {
    if (Platform.isMacOS) {
      try {
        final result = Process.runSync("sysctl", const ["-n", "machdep.cpu.brand_string"]);
        if (result.exitCode == 0) return (result.stdout as String).trim();
        stderr.writeln("sysctl CPU query failed with exit code ${result.exitCode}: ${result.stderr}");
      } on ProcessException catch (error, stackTrace) {
        stderr.writeln("sysctl CPU query failed: $error");
        stderr.writeln(stackTrace);
      }
      return null;
    }
    if (Platform.isLinux) {
      try {
        final modelLine = File(
          "/proc/cpuinfo",
        ).readAsLinesSync().where((line) => line.startsWith("model name")).firstOrNull;
        return modelLine?.split(":").last.trim();
      } on Object catch (error, stackTrace) {
        stderr.writeln("Linux CPU query failed: $error");
        stderr.writeln(stackTrace);
        return null;
      }
    }
    if (Platform.isWindows) return Platform.environment["PROCESSOR_IDENTIFIER"];
    return null;
  }
}

String _projectId({required int index}) => "/benchmark/project-${index.toString().padLeft(4, "0")}";

String _sessionId({required String prefix, required int index}) => "$prefix-${index.toString().padLeft(5, "0")}";

mixin _PluginCounters {
  int calls = 0;
  int rowsEnumerated = 0;

  void recordCall({required int rows}) {
    calls++;
    rowsEnumerated += rows;
  }

  void resetCounters() {
    calls = 0;
    rowsEnumerated = 0;
  }
}

class _PluginCounterAggregate {
  const _PluginCounterAggregate({required this.plugins});

  final List<_ThrowingBenchmarkPlugin> plugins;

  int get pluginCount => plugins.length;
  int get calls => plugins.fold(0, (total, plugin) => total + plugin.calls);
  int get rowsEnumerated => plugins.fold(0, (total, plugin) => total + plugin.rowsEnumerated);

  void resetCounters() {
    for (final plugin in plugins) {
      plugin.resetCounters();
    }
  }
}

class _ThrowingBenchmarkPlugin with _PluginCounters implements NativeProjectsPluginApi {
  _ThrowingBenchmarkPlugin({required this.id});

  @override
  final String id;

  @override
  Future<List<PluginProject>> getProjects() => _throwListRead(read: "projects");

  @override
  Future<PluginProject> getProject(String projectId) => _throwListRead(read: "project detail");

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) =>
      _throwListRead(read: "root sessions");

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) => _throwListRead(read: "child sessions");

  Never _throwListRead({required String read}) {
    recordCall(rows: 0);
    throw StateError("catalog benchmark unexpectedly called $read on plugin $id");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recordCall(rows: 0);
    throw StateError("catalog benchmark unexpectedly called ${invocation.memberName} on plugin $id");
  }
}

class _ExistingFilesystemApi implements FilesystemApi {
  @override
  bool directoryExists(String path) => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
