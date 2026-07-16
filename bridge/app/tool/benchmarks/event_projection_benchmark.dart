import "dart:convert";
import "dart:ffi" show Abi;
import "dart:io";

import "package:args/args.dart";
import "package:drift/native.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/session_event_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/trackers/session_event_tracker.dart";
import "package:sesori_bridge/src/bridge/services/session_event_service.dart";
import "package:sesori_bridge/src/bridge/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/sse/bridge_event_mapper.dart";
import "package:sesori_bridge/src/bridge/sse/sse_manager.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

const _defaultWarmupCount = 25;
const _defaultSampleCount = 2000;
const _pluginId = "event-benchmark";
const _projectId = "/benchmark/event-projection";
const _sessionId = "ses_benchmark_known_root";
const _backendSessionId = "backend-known-root";
const _defaultTimestamp = 1700000000000;

Future<void> main(List<String> arguments) async {
  try {
    final configuration = _BenchmarkConfiguration.parse(arguments: arguments);
    final report = await _EventProjectionBenchmark(configuration: configuration).run();
    stdout.writeln(const JsonEncoder.withIndent("  ").convert(report));
  } on Object catch (error, stackTrace) {
    stderr.writeln("event-projection benchmark failed: $error");
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

class _EventProjectionBenchmark {
  const _EventProjectionBenchmark({required _BenchmarkConfiguration configuration}) : _configuration = configuration;

  final _BenchmarkConfiguration _configuration;

  Future<Map<String, Object?>> run() async {
    final rssBefore = ProcessInfo.currentRss;
    final temporaryDirectory = await Directory.systemTemp.createTemp("sesori-event-projection-");
    final databaseFile = File(p.join(temporaryDirectory.path, "benchmark.sqlite"));
    AppDatabase? database;
    SessionRepository? repository;
    SessionMutationDispatcher? mutationDispatcher;
    SSEManager? sseManager;

    try {
      database = AppDatabase(NativeDatabase.createInBackground(databaseFile));
      final sqliteVersion = await _sqliteVersion(database: database);
      await _seed(database: database);
      final plugin = _BenchmarkPlugin();
      repository = SessionRepository(
        plugin: plugin,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
        pullRequestDao: database.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      mutationDispatcher = SessionMutationDispatcher(sessionRepository: repository);
      final failureReporter = _BenchmarkFailureReporter();
      final service = SessionEventService(
        sessionRepository: repository,
        sessionMutationDispatcher: mutationDispatcher,
        eventMapper: const SessionEventMapper(),
        eventTracker: SessionEventTracker(
          maxPendingEntries: SessionEventTracker.defaultMaxPendingEntries,
        ),
        failureReporter: failureReporter,
      );
      final bridgeEventMapper = BridgeEventMapper(failureReporter: failureReporter);
      sseManager = SSEManager(
        replayWindow: const Duration(minutes: 1),
        onBytesSent: (_) {},
        failureReporter: failureReporter,
      );
      final scenario = await _measureKnownRootUpdates(
        database: database,
        service: service,
        bridgeEventMapper: bridgeEventMapper,
        sseManager: sseManager,
      );
      final rssAfter = ProcessInfo.currentRss;
      final databaseSchemaVersion = database.schemaVersion;
      sseManager.stop();
      sseManager = null;
      await mutationDispatcher.dispose();
      mutationDispatcher = null;
      await repository.dispose();
      repository = null;
      await database.close();
      database = null;
      final databaseBytes = databaseFile.lengthSync();

      return {
        "schemaVersion": 1,
        "benchmark": "event_projection_benchmark",
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
        "scenarios": [scenario],
      };
    } finally {
      sseManager?.stop();
      if (mutationDispatcher != null) await mutationDispatcher.dispose();
      if (repository != null) await repository.dispose();
      if (database != null) await database.close();
      try {
        await temporaryDirectory.delete(recursive: true);
      } on FileSystemException catch (error, stackTrace) {
        stderr.writeln("could not delete benchmark directory ${temporaryDirectory.path}: $error");
        stderr.writeln(stackTrace);
      }
    }
  }

  Future<Map<String, Object?>> _measureKnownRootUpdates({
    required AppDatabase database,
    required SessionEventService service,
    required BridgeEventMapper bridgeEventMapper,
    required SSEManager sseManager,
  }) async {
    sseManager.subscribePath(1, "/global/event", _BenchmarkRelayClient());
    sseManager.unsubscribe(1);
    if (sseManager.pendingReplayCount != 1) {
      throw StateError("benchmark relay replay queue was not created");
    }
    for (var index = 0; index < _configuration.warmupCount; index++) {
      await _projectAndEnqueue(
        service: service,
        bridgeEventMapper: bridgeEventMapper,
        sseManager: sseManager,
        title: "warmup-$index",
        updatedAt: _defaultTimestamp + index,
      );
    }

    final samples = <int>[];
    for (var index = 0; index < _configuration.sampleCount; index++) {
      final stopwatch = Stopwatch()..start();
      await _projectAndEnqueue(
        service: service,
        bridgeEventMapper: bridgeEventMapper,
        sseManager: sseManager,
        title: "sample-$index",
        updatedAt: _defaultTimestamp + _configuration.warmupCount + index,
      );
      stopwatch.stop();
      samples.add(stopwatch.elapsedMicroseconds);
    }
    final finalIndex = _configuration.sampleCount - 1;
    final finalTitle = "sample-$finalIndex";
    final finalUpdatedAt = _defaultTimestamp + _configuration.warmupCount + finalIndex;
    final row = await database.sessionDao.getSession(sessionId: _sessionId);
    if (row?.catalogTitle != finalTitle || row?.updatedAt != finalUpdatedAt) {
      throw StateError("catalog projection did not commit the final measured update");
    }
    samples.sort();

    return {
      "name": "known_root_update_to_catalog_commit_and_relay_enqueue",
      "fixture": {
        "pluginCount": 1,
        "knownRootCount": 1,
        "eventType": "session.updated",
        "pendingEventBound": SessionEventTracker.defaultMaxPendingEntries,
        "relaySubscriberCount": 0,
        "relayReplayQueueCount": 1,
        "measuredPath": "normalize-project-map-enqueue",
      },
      "warmupCount": _configuration.warmupCount,
      "sampleCount": _configuration.sampleCount,
      "latencyMicroseconds": {
        "p50": _nearestRank(sortedSamples: samples, percentile: 0.50),
        "p95": _nearestRank(sortedSamples: samples, percentile: 0.95),
        "p99": _nearestRank(sortedSamples: samples, percentile: 0.99),
        "max": samples.last,
      },
      "totals": {
        "eventsProcessed": _configuration.sampleCount,
        "catalogRowsWritten": _configuration.sampleCount,
        "relayEventsEnqueued": _configuration.sampleCount,
        "pluginCalls": 0,
      },
      "perSample": {
        "eventsProcessed": 1,
        "catalogRowsWritten": 1,
        "relayEventsEnqueued": 1,
        "pluginCalls": 0,
      },
    };
  }

  Future<void> _projectAndEnqueue({
    required SessionEventService service,
    required BridgeEventMapper bridgeEventMapper,
    required SSEManager sseManager,
    required String title,
    required int updatedAt,
  }) async {
    final output = await service.normalize(
      source: service.captureSource(
        pluginId: _pluginId,
        event: BridgeSseSessionUpdated(
          info: Session(
            id: _backendSessionId,
            pluginId: _pluginId,
            projectID: _projectId,
            directory: _projectId,
            parentID: null,
            title: title,
            time: SessionTime(
              created: _defaultTimestamp,
              updated: updatedAt,
              archived: null,
            ),
            pullRequest: null,
            promptDefaults: null,
          ).toJson(),
          titleChanged: false,
        ),
      ),
    );
    if (output.length != 1) {
      throw StateError("event projection emitted ${output.length} events; expected 1");
    }
    final mapped = bridgeEventMapper.map(output.single);
    if (mapped == null) throw StateError("projected session update did not map to a shared event");
    sseManager.enqueueEvent(mapped);
  }

  Future<void> _seed({required AppDatabase database}) async {
    await database.projectsDao.recordOpenedProject(
      projectId: _projectId,
      path: _projectId,
      createdAt: _defaultTimestamp,
      updatedAt: _defaultTimestamp,
    );
    await database.sessionDao.insertSession(
      sessionId: _sessionId,
      backendSessionId: _backendSessionId,
      projectId: _projectId,
      isDedicated: false,
      createdAt: _defaultTimestamp,
      worktreePath: null,
      branchName: null,
      baseBranch: null,
      baseCommit: null,
      lastAgent: null,
      lastAgentModel: null,
      pluginId: _pluginId,
    );
  }

  int _nearestRank({required List<int> sortedSamples, required double percentile}) {
    final rank = (percentile * sortedSamples.length).ceil();
    return sortedSamples[rank - 1];
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
    return {
      "sha": _gitOutput(arguments: const ["rev-parse", "HEAD"]),
      "branch": _gitOutput(arguments: const ["rev-parse", "--abbrev-ref", "HEAD"]),
      "dirty": _gitOutput(arguments: const ["status", "--porcelain"])?.isNotEmpty,
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

class _BenchmarkPlugin implements NativeProjectsPluginApi {
  @override
  String get id => _pluginId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BenchmarkRelayClient implements RelayClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BenchmarkFailureReporter implements FailureReporter {
  @override
  void log({required String message}) {}

  @override
  Future<void> recordFailure({
    required Object error,
    required StackTrace stackTrace,
    required String uniqueIdentifier,
    required bool fatal,
    required String? reason,
    required Iterable<Object> information,
  }) async {
    throw StateError("benchmark path reported $uniqueIdentifier: $error");
  }

  @override
  void setGlobalKey({required String key, required Object value}) {}
}
