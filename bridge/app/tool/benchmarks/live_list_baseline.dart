import "dart:convert";
import "dart:ffi" show Abi;
import "dart:io";

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
const _defaultTimestamp = 1700000000000;
const _projectDirectory = "/benchmark/project-0000";
const _smallProjectDirectory = "/benchmark/project-0001";

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
  const _BenchmarkConfiguration({required this.warmupCount, required this.sampleCount});

  final int warmupCount;
  final int sampleCount;

  static _BenchmarkConfiguration parse({required List<String> arguments}) {
    final parser = ArgParser()
      ..addOption("warmup", defaultsTo: "$_defaultWarmupCount")
      ..addOption("samples", defaultsTo: "$_defaultSampleCount");
    final parsed = parser.parse(arguments);
    final warmupCount = int.tryParse(parsed.option("warmup") ?? "");
    final sampleCount = int.tryParse(parsed.option("samples") ?? "");
    if (warmupCount == null || warmupCount < 0) {
      throw const FormatException("--warmup must be a non-negative integer");
    }
    if (sampleCount == null || sampleCount < 1) {
      throw const FormatException("--samples must be a positive integer");
    }
    return _BenchmarkConfiguration(warmupCount: warmupCount, sampleCount: sampleCount);
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
      final scenarios = await _runScenarios(database: database);
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
          "driftSchemaVersion": databaseSchemaVersion,
          "fileBacked": true,
          "temporary": true,
          "bytes": databaseBytes,
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
    await _seedProjects(database: database);
    final plugin = _ThrowingBenchmarkPlugin();
    final filesystemApi = _ExistingFilesystemApi();
    const unseenCalculator = SessionUnseenCalculator();
    // Never invoked by the benchmarked listing paths; wired only to satisfy
    // the repository constructor.
    final gitCliApi = GitCliApi(processRunner: ProcessRunner(), gitPathExists: ({required String gitPath}) => false);

    final projectRepository = ProjectRepository(
      gitCliApi: gitCliApi,
      operationalPlugins: {plugin.id: plugin},
      defaultEnabledPluginId: plugin.id,
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
        name: "catalog_500_projects",
        fixture: const {
          "source": "catalog",
          "projectCount": 500,
        },
        expectedRowsReturned: 500,
        plugin: plugin,
        operation: () async => (await projectRepository.getProjects()).length,
      ),
    );
    await _seedSessions(database: database);

    final sessionRepository = _sessionRepository(database: database, plugin: plugin);
    final mutationDispatcher = SessionMutationDispatcher(sessionRepository: sessionRepository);

    try {
      results.add(
        await _measure(
          name: "catalog_100_of_10000_endpoint_core_without_pr_refresh",
          fixture: const {
            "source": "catalog",
            "measuredPath": "endpoint-core-without-pr-refresh",
            "sessionCount": 10000,
            "start": 0,
            "limit": 100,
          },
          expectedRowsReturned: 100,
          plugin: plugin,
          operation: () => _sessionEndpointCoreCount(
            repository: sessionRepository,
            mutationDispatcher: mutationDispatcher,
            projectId: _projectDirectory,
            start: 0,
            limit: 100,
          ),
        ),
      );
      results.add(
        await _measure(
          name: "catalog_1000_unpaginated_endpoint_core_without_pr_refresh",
          fixture: const {
            "source": "catalog",
            "measuredPath": "endpoint-core-without-pr-refresh",
            "sessionCount": 1000,
            "start": null,
            "limit": null,
          },
          expectedRowsReturned: 1000,
          plugin: plugin,
          operation: () => _sessionEndpointCoreCount(
            repository: sessionRepository,
            mutationDispatcher: mutationDispatcher,
            projectId: _smallProjectDirectory,
            start: null,
            limit: null,
          ),
        ),
      );
      return results;
    } finally {
      await mutationDispatcher.dispose();
      await sessionRepository.dispose();
    }
  }

  Future<void> _seedProjects({required AppDatabase database}) async {
    await database.projectsDao.upsertProjectRows(
      rows: [
        for (var index = 0; index < 500; index++)
          ProjectDto(
            projectId: "/benchmark/project-${index.toString().padLeft(4, "0")}",
            path: "/benchmark/project-${index.toString().padLeft(4, "0")}",
            hidden: false,
            baseBranch: null,
            displayName: "project-${index.toString().padLeft(4, "0")}",
            createdAt: _defaultTimestamp + index,
            updatedAt: _defaultTimestamp + index,
            projectionUpdatedAt: _defaultTimestamp + index,
          ),
      ],
    );
  }

  Future<void> _seedSessions({required AppDatabase database}) async {
    await database.sessionDao.upsertSessionRows(
      rows: [
        ..._sessions(count: 10000, projectId: _projectDirectory, idPrefix: "large"),
        ..._sessions(count: 1000, projectId: _smallProjectDirectory, idPrefix: "small"),
      ],
    );
  }

  SessionRepository _sessionRepository({required AppDatabase database, required BridgePluginApi plugin}) {
    return SessionRepository(
      operationalPlugins: {plugin.id: plugin},
      enabledPluginIds: [plugin.id],
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
    return sessions.length;
  }

  Future<Map<String, Object?>> _measure({
    required String name,
    required Map<String, Object?> fixture,
    required int expectedRowsReturned,
    required _PluginCounters plugin,
    required Future<int> Function() operation,
  }) async {
    for (var index = 0; index < _configuration.warmupCount; index++) {
      final rows = await operation();
      _verifyRows(name: name, expected: expectedRowsReturned, actual: rows);
    }
    plugin.resetCounters();

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
    if (plugin.calls != 0) {
      throw StateError("$name made ${plugin.calls} plugin calls; expected zero");
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
        "pluginCalls": plugin.calls,
        "pluginRowsEnumerated": plugin.rowsEnumerated,
        "rowsReturned": rowsReturned,
      },
      "perSample": {
        "pluginCalls": plugin.calls / _configuration.sampleCount,
        "pluginRowsEnumerated": plugin.rowsEnumerated / _configuration.sampleCount,
        "rowsReturned": rowsReturned / _configuration.sampleCount,
      },
    };
  }

  void _verifyRows({required String name, required int expected, required int actual}) {
    if (actual != expected) {
      throw StateError("$name returned $actual rows; expected $expected");
    }
  }

  int _nearestRank({required List<int> sortedSamples, required double percentile}) {
    final rank = (percentile * sortedSamples.length).ceil();
    return sortedSamples[rank - 1];
  }

  List<SessionDto> _sessions({required int count, required String projectId, required String idPrefix}) {
    return List<SessionDto>.generate(
      count,
      (index) => SessionDto(
        sessionId: "$idPrefix-${index.toString().padLeft(5, "0")}",
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
        pluginId: "catalog-benchmark",
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

class _ThrowingBenchmarkPlugin with _PluginCounters implements NativeProjectsPluginApi {
  @override
  String get id => "catalog-benchmark";

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recordCall(rows: 0);
    throw StateError("catalog benchmark unexpectedly called plugin member ${invocation.memberName}");
  }
}

class _ExistingFilesystemApi implements FilesystemApi {
  @override
  bool directoryExists(String path) => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
