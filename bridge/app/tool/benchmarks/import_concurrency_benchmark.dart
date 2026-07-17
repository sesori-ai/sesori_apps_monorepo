import "dart:async";
import "dart:convert";
import "dart:ffi" show Abi;
import "dart:io";

import "package:args/args.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/daos/projects_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/projects_table.dart";
import "package:sesori_bridge/src/repositories/catalog_import_repository.dart";
import "package:sesori_bridge/src/repositories/models/catalog_import_control.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

const _defaultProjectCount = 500;
const _defaultSessionCount = 10000;
const _defaultWarmupCount = 10;
const _defaultSampleCount = 100;
const _defaultTimestamp = 1700000000000;
const _pluginId = "import-benchmark";

Future<void> main(List<String> arguments) async {
  try {
    final configuration = _BenchmarkConfiguration.parse(arguments: arguments);
    final report = await _ImportConcurrencyBenchmark(configuration: configuration).run();
    stdout.writeln(const JsonEncoder.withIndent("  ").convert(report));
  } on Object catch (error, stackTrace) {
    stderr.writeln("import-concurrency benchmark failed: $error");
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

class _BenchmarkConfiguration {
  const _BenchmarkConfiguration({
    required this.projectCount,
    required this.sessionCount,
    required this.warmupCount,
    required this.sampleCount,
  });

  final int projectCount;
  final int sessionCount;
  final int warmupCount;
  final int sampleCount;

  static _BenchmarkConfiguration parse({required List<String> arguments}) {
    final parser = ArgParser()
      ..addOption("projects", defaultsTo: "$_defaultProjectCount")
      ..addOption("sessions", defaultsTo: "$_defaultSessionCount")
      ..addOption("warmup", defaultsTo: "$_defaultWarmupCount")
      ..addOption("samples", defaultsTo: "$_defaultSampleCount");
    final parsed = parser.parse(arguments);
    final projectCount = int.tryParse(parsed.option("projects") ?? "");
    final sessionCount = int.tryParse(parsed.option("sessions") ?? "");
    final warmupCount = int.tryParse(parsed.option("warmup") ?? "");
    final sampleCount = int.tryParse(parsed.option("samples") ?? "");
    if (projectCount == null || projectCount < 1) {
      throw const FormatException("--projects must be a positive integer");
    }
    if (sessionCount == null || sessionCount < 1) {
      throw const FormatException("--sessions must be a positive integer");
    }
    if (warmupCount == null || warmupCount < 0) {
      throw const FormatException("--warmup must be a non-negative integer");
    }
    if (sampleCount == null || sampleCount < 1) {
      throw const FormatException("--samples must be a positive integer");
    }
    return _BenchmarkConfiguration(
      projectCount: projectCount,
      sessionCount: sessionCount,
      warmupCount: warmupCount,
      sampleCount: sampleCount,
    );
  }
}

class _ImportConcurrencyBenchmark {
  const _ImportConcurrencyBenchmark({required _BenchmarkConfiguration configuration}) : _configuration = configuration;

  final _BenchmarkConfiguration _configuration;

  Future<Map<String, Object?>> run() async {
    final rssBefore = ProcessInfo.currentRss;
    final temporaryDirectory = await Directory.systemTemp.createTemp("sesori-import-concurrency-");
    final databaseFile = File(p.join(temporaryDirectory.path, "benchmark.sqlite"));
    AppDatabase? database;

    try {
      database = AppDatabase.openFile(file: databaseFile);
      final sqliteVersion = await _sqliteVersion(database: database);
      final fixture = _fixture(rootDirectory: temporaryDirectory.path);
      await _seed(database: database, projectPaths: fixture.projectPaths);

      final releaseEnumeration = Completer<void>();
      final publicationTransactionStarted = Completer<void>();
      final releasePublicationTransaction = Completer<void>();
      final plugin = _BenchmarkPlugin(
        launchDirectory: fixture.projectPaths.first,
        sessions: fixture.sessions,
        releaseEnumeration: releaseEnumeration,
      );
      final repository = CatalogImportRepository(
        operationalPlugins: {plugin.id: plugin},
        projectsDao: _BenchmarkProjectsDao(
          database,
          publicationStarted: publicationTransactionStarted,
          releasePublication: releasePublicationTransaction,
        ),
        sessionDao: database.sessionDao,
        catalogHydrationsDao: database.catalogHydrationsDao,
        projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
      );
      final importDone = Completer<void>();
      final publicationStopwatch = Stopwatch();
      final importSubscription = repository
          .importCatalog(
            pluginId: plugin.id,
            control: CatalogImportControl(
              explicitImportRequested: false,
              hydrationMarkerRequested: true,
            ),
          )
          .listen(
            (progress) {
              if (progress is CatalogImportCommitting) {
                publicationStopwatch.start();
              } else if (progress is CatalogImportCompleted) {
                publicationStopwatch.stop();
                if (!importDone.isCompleted) importDone.complete();
              }
            },
            onError: importDone.completeError,
          );
      await plugin.enumerationStarted.future;

      for (var index = 0; index < _configuration.warmupCount; index++) {
        await database.projectsDao.getCatalogProjects();
      }
      final blockedEnumerationReadSamples = <int>[];
      for (var index = 0; index < _configuration.sampleCount; index++) {
        final stopwatch = Stopwatch()..start();
        final rows = await database.projectsDao.getCatalogProjects();
        stopwatch.stop();
        if (rows.length != _configuration.projectCount) {
          throw StateError("catalog read returned ${rows.length} projects; expected ${_configuration.projectCount}");
        }
        blockedEnumerationReadSamples.add(stopwatch.elapsedMicroseconds);
      }

      final schedulingProbe = _SchedulingLagProbe()..start();
      releaseEnumeration.complete();
      await publicationTransactionStarted.future;
      final publicationReadStopwatch = Stopwatch()..start();
      final publicationRows = await database.projectsDao.getCatalogProjects();
      publicationReadStopwatch.stop();
      final publicationReadCompletedDuringImport = !importDone.isCompleted;
      releasePublicationTransaction.complete();
      await importDone.future;
      schedulingProbe.stop();
      await importSubscription.cancel();
      if (publicationRows.length != _configuration.projectCount) {
        throw StateError("publication read returned ${publicationRows.length} projects");
      }
      final hydration = await repository.getHydrationCompletion(pluginId: plugin.id);
      if (hydration == null) throw StateError("import did not atomically record hydration completion");

      final rssAfter = ProcessInfo.currentRss;
      final databaseSchemaVersion = database.schemaVersion;
      await database.close();
      database = null;
      final databaseBytes = databaseFile.lengthSync();
      blockedEnumerationReadSamples.sort();
      final schedulingSamples = schedulingProbe.samples..sort();

      return {
        "schemaVersion": 1,
        "benchmark": "import_concurrency_benchmark",
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
        "fixture": {
          "pluginCount": 1,
          "capability": "bridge-derived-projects",
          "projectCount": _configuration.projectCount,
          "rootSessionCount": _configuration.sessionCount,
          "projectionVersion": CatalogImportRepository.projectionVersion,
          "catalogState": "projects-only-first-hydration",
        },
        "catalogReadWhileEnumerationBlockedMicroseconds": _percentiles(blockedEnumerationReadSamples),
        "catalogReadOverPublicationMicroseconds": publicationReadStopwatch.elapsedMicroseconds,
        "catalogReadCompletedDuringImport": publicationReadCompletedDuringImport,
        "publicationMicroseconds": publicationStopwatch.elapsedMicroseconds,
        "schedulingLagMicroseconds": _percentiles(schedulingSamples),
        "rssBytes": {
          "before": rssBefore,
          "after": rssAfter,
          "delta": rssAfter - rssBefore,
        },
      };
    } finally {
      if (database != null) await database.close();
      try {
        await temporaryDirectory.delete(recursive: true);
      } on FileSystemException catch (error, stackTrace) {
        stderr.writeln("could not delete benchmark directory ${temporaryDirectory.path}: $error");
        stderr.writeln(stackTrace);
      }
    }
  }

  ({List<String> projectPaths, List<PluginSession> sessions}) _fixture({required String rootDirectory}) {
    final projectPaths = List<String>.generate(
      _configuration.projectCount,
      (index) => p.join(rootDirectory, "project-${index.toString().padLeft(4, "0")}"),
      growable: false,
    );
    final sessions = List<PluginSession>.generate(
      _configuration.sessionCount,
      (index) {
        final projectPath = projectPaths[index % projectPaths.length];
        return PluginSession(
          id: "backend-${index.toString().padLeft(6, "0")}",
          projectID: projectPath,
          directory: projectPath,
          parentID: null,
          title: "Session $index imported",
          time: PluginSessionTime(
            created: _defaultTimestamp + index,
            updated: _defaultTimestamp + index + 1,
            archived: null,
          ),
        );
      },
      growable: false,
    );
    return (projectPaths: projectPaths, sessions: sessions);
  }

  Future<void> _seed({
    required AppDatabase database,
    required List<String> projectPaths,
  }) async {
    await database.projectsDao.upsertProjectRows(
      rows: [
        for (var index = 0; index < projectPaths.length; index++)
          ProjectDto(
            projectId: projectPaths[index],
            path: projectPaths[index],
            hidden: false,
            baseBranch: null,
            displayName: null,
            createdAt: _defaultTimestamp,
            updatedAt: _defaultTimestamp,
            projectionUpdatedAt: _defaultTimestamp,
          ),
      ],
    );
  }

  Future<String> _sqliteVersion({required AppDatabase database}) async {
    final row = await database.customSelect("SELECT sqlite_version() AS version").getSingle();
    return row.read<String>("version");
  }

  Map<String, Object?> _hostMetadata() => {
    "operatingSystem": Platform.operatingSystem,
    "operatingSystemVersion": Platform.operatingSystemVersion,
    "architecture": Abi.current().toString(),
    "logicalProcessors": Platform.numberOfProcessors,
    "cpuModel": _cpuModel(),
  };

  Map<String, Object?> _runtimeMetadata() => {
    "dartVersion": Platform.version,
    "productMode": const bool.fromEnvironment("dart.vm.product"),
  };

  Map<String, Object?> _commitMetadata() => {
    "sha": _gitOutput(arguments: const ["rev-parse", "HEAD"]),
    "branch": _gitOutput(arguments: const ["rev-parse", "--abbrev-ref", "HEAD"]),
    "dirty": _gitOutput(arguments: const ["status", "--porcelain"])?.isNotEmpty,
  };

  String? _gitOutput({required List<String> arguments}) {
    try {
      final result = Process.runSync("git", arguments);
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trim();
    } on ProcessException {
      return null;
    }
  }

  String? _cpuModel() {
    if (Platform.isMacOS) {
      final result = Process.runSync("sysctl", const ["-n", "machdep.cpu.brand_string"]);
      return result.exitCode == 0 ? (result.stdout as String).trim() : null;
    }
    if (Platform.isWindows) return Platform.environment["PROCESSOR_IDENTIFIER"];
    return null;
  }

  Map<String, int> _percentiles(List<int> sortedSamples) {
    if (sortedSamples.isEmpty) return const {"p50": 0, "p95": 0, "p99": 0, "max": 0};
    return {
      "p50": _nearestRank(sortedSamples: sortedSamples, percentile: 0.50),
      "p95": _nearestRank(sortedSamples: sortedSamples, percentile: 0.95),
      "p99": _nearestRank(sortedSamples: sortedSamples, percentile: 0.99),
      "max": sortedSamples.last,
    };
  }

  int _nearestRank({required List<int> sortedSamples, required double percentile}) {
    final rank = (percentile * sortedSamples.length).ceil();
    return sortedSamples[rank - 1];
  }
}

class _SchedulingLagProbe {
  final List<int> samples = <int>[];
  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  bool _running = false;

  void start() {
    _running = true;
    _stopwatch.start();
    _schedule();
  }

  void _schedule() {
    final expected = _stopwatch.elapsedMicroseconds + 1000;
    _timer = Timer(const Duration(milliseconds: 1), () {
      if (!_running) return;
      final actual = _stopwatch.elapsedMicroseconds;
      samples.add(actual > expected ? actual - expected : 0);
      _schedule();
    });
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _stopwatch.stop();
  }
}

class _BenchmarkProjectsDao extends ProjectsDao {
  _BenchmarkProjectsDao(
    super.attachedDatabase, {
    required this.publicationStarted,
    required this.releasePublication,
  });

  final Completer<void> publicationStarted;
  final Completer<void> releasePublication;

  @override
  Future<void> upsertProjectRows({required List<ProjectDto> rows}) async {
    await super.upsertProjectRows(rows: rows);
    publicationStarted.complete();
    await releasePublication.future;
  }
}

class _BenchmarkPlugin implements BridgeDerivedProjectsPluginApi {
  _BenchmarkPlugin({
    required this.launchDirectory,
    required this.sessions,
    required this.releaseEnumeration,
  });

  @override
  final String launchDirectory;
  final List<PluginSession> sessions;
  final Completer<void> releaseEnumeration;
  final Completer<void> enumerationStarted = Completer<void>();

  @override
  String get id => _pluginId;

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    enumerationStarted.complete();
    await releaseEnumeration.future;
    return sessions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
