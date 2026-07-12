import "dart:convert";
import "dart:ffi" show Abi;
import "dart:io";

import "package:args/args.dart";
import "package:drift/native.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

const _defaultWarmupCount = 25;
const _defaultSampleCount = 2000;
const _defaultTimestamp = 1700000000000;
const _projectDirectory = "/benchmark/live-list-project";

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
    final databaseFile = File("${temporaryDirectory.path}${Platform.pathSeparator}benchmark.sqlite");
    AppDatabase? database;

    try {
      database = AppDatabase(NativeDatabase.createInBackground(databaseFile));
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
    final projects = List<PluginProject>.generate(
      500,
      (index) => PluginProject(
        id: "/benchmark/project-${index.toString().padLeft(4, "0")}",
        name: "project-${index.toString().padLeft(4, "0")}",
        activity: PluginProjectActivity(
          createdAt: _defaultTimestamp + index,
          updatedAt: _defaultTimestamp + index,
        ),
      ),
      growable: false,
    );
    final sessions10000 = _sessions(count: 10000);
    final sessions1000 = sessions10000.sublist(0, 1000);
    final nativeLarge = _NativeBenchmarkPlugin(projects: projects, sessions: sessions10000);
    final nativeSmall = _NativeBenchmarkPlugin(projects: const [], sessions: sessions1000);
    final derivedLarge = _DerivedBenchmarkPlugin(sessions: sessions10000);
    final derivedSmall = _DerivedBenchmarkPlugin(sessions: sessions1000);
    final filesystemApi = _ExistingFilesystemApi();
    const unseenCalculator = SessionUnseenCalculator();

    final projectRepository = ProjectRepository(
      plugin: nativeLarge,
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      unseenCalculator: unseenCalculator,
      filesystemApi: filesystemApi,
    );
    final results = <Map<String, Object?>>[];
    results.add(
      await _measure(
        name: "native_500_projects",
        fixture: const {
          "capability": "native-projects",
          "projectCount": 500,
        },
        expectedRowsReturned: 500,
        plugin: nativeLarge,
        operation: () async => (await projectRepository.getProjects(defaultTimestamp: _defaultTimestamp)).length,
      ),
    );

    await database.projectsDao.insertMissingProjectsWithActivity(
      activities: const {
        _projectDirectory: (createdAt: _defaultTimestamp, updatedAt: _defaultTimestamp),
      },
    );
    final nativeLargeRepository = _sessionRepository(database: database, plugin: nativeLarge);
    final nativeSmallRepository = _sessionRepository(database: database, plugin: nativeSmall);
    final derivedLargeRepository = _sessionRepository(database: database, plugin: derivedLarge);
    final derivedSmallRepository = _sessionRepository(database: database, plugin: derivedSmall);

    results.add(
      await _measure(
        name: "native_100_of_10000_sessions",
        fixture: const {
          "capability": "native-projects",
          "sessionCount": 10000,
          "start": 0,
          "limit": 100,
        },
        expectedRowsReturned: 100,
        plugin: nativeLarge,
        operation: () async => (await nativeLargeRepository.getSessionsForProject(
          projectId: _projectDirectory,
          start: 0,
          limit: 100,
        )).length,
      ),
    );
    results.add(
      await _measure(
        name: "native_1000_unpaginated_sessions",
        fixture: const {
          "capability": "native-projects",
          "sessionCount": 1000,
          "start": null,
          "limit": null,
        },
        expectedRowsReturned: 1000,
        plugin: nativeSmall,
        operation: () async => (await nativeSmallRepository.getSessionsForProject(
          projectId: _projectDirectory,
          start: null,
          limit: null,
        )).length,
      ),
    );
    results.add(
      await _measure(
        name: "derived_100_of_10000_global_enumeration",
        fixture: const {
          "capability": "bridge-derived-projects",
          "sessionCount": 10000,
          "start": 0,
          "limit": 100,
        },
        expectedRowsReturned: 100,
        plugin: derivedLarge,
        operation: () async => (await derivedLargeRepository.getSessionsForProject(
          projectId: _projectDirectory,
          start: 0,
          limit: 100,
        )).length,
      ),
    );
    results.add(
      await _measure(
        name: "derived_1000_unpaginated_sessions",
        fixture: const {
          "capability": "bridge-derived-projects",
          "sessionCount": 1000,
          "start": null,
          "limit": null,
        },
        expectedRowsReturned: 1000,
        plugin: derivedSmall,
        operation: () async => (await derivedSmallRepository.getSessionsForProject(
          projectId: _projectDirectory,
          start: null,
          limit: null,
        )).length,
      ),
    );
    return results;
  }

  SessionRepository _sessionRepository({required AppDatabase database, required BridgePluginApi plugin}) {
    return SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      pullRequestRepository: PullRequestRepository(
        pullRequestDao: database.pullRequestDao,
        projectsDao: database.projectsDao,
      ),
      unseenCalculator: const SessionUnseenCalculator(),
    );
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

  List<PluginSession> _sessions({required int count}) {
    return List<PluginSession>.generate(
      count,
      (index) => PluginSession(
        id: "session-${index.toString().padLeft(5, "0")}",
        projectID: _projectDirectory,
        directory: _projectDirectory,
        parentID: null,
        title: "Session $index",
        time: PluginSessionTime(
          created: _defaultTimestamp + index,
          updated: _defaultTimestamp + index,
          archived: null,
        ),
        summary: const PluginSessionSummary(additions: 1, deletions: 0, files: 1),
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
      } on FileSystemException catch (error, stackTrace) {
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

class _NativeBenchmarkPlugin with _PluginCounters implements NativeProjectsPluginApi {
  _NativeBenchmarkPlugin({required this.projects, required this.sessions});

  final List<PluginProject> projects;
  final List<PluginSession> sessions;

  @override
  String get id => "native-benchmark";

  @override
  Future<List<PluginProject>> getProjects() async {
    recordCall(rows: projects.length);
    return projects;
  }

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) async {
    final from = start ?? 0;
    final until = limit == null ? sessions.length : (from + limit).clamp(0, sessions.length);
    final result = sessions.sublist(from, until);
    recordCall(rows: result.length);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DerivedBenchmarkPlugin with _PluginCounters implements BridgeDerivedProjectsPluginApi {
  _DerivedBenchmarkPlugin({required this.sessions});

  final List<PluginSession> sessions;

  @override
  String get id => "derived-benchmark";

  @override
  String get launchDirectory => _projectDirectory;

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    recordCall(rows: sessions.length);
    return sessions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ExistingFilesystemApi implements FilesystemApi {
  @override
  bool directoryExists(String path) => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
