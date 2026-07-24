import "dart:async";
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
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/session_event_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/trackers/session_event_tracker.dart";
import "package:sesori_bridge/src/bridge/services/session_event_service.dart";
import "package:sesori_bridge/src/bridge/sse/bridge_event_mapper.dart";
import "package:sesori_bridge/src/bridge/sse/sse_manager.dart";
import "package:sesori_bridge/src/repositories/catalog_import_repository.dart";
import "package:sesori_bridge/src/repositories/models/catalog_import_control.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "benchmark_plugin_runtime.dart";

const _defaultProjectCount = 2000;
const _defaultSessionCount = 50000;
const _defaultEventCount = 2000;
const _defaultWarmupCount = 25;
const _defaultReadSampleCount = 2000;
const _catalogTimestamp = 1700000000000;
const _eventTimestamp = 1900000000000;
const _pluginId = "catalog-soak";
const _sentinelSessionId = "ses_catalog_soak_sentinel";

Future<void> main(List<String> arguments) async {
  try {
    final configuration = _BenchmarkConfiguration.parse(arguments: arguments);
    final report = await _CatalogImportEventSoak(configuration: configuration).run();
    stdout.writeln(const JsonEncoder.withIndent("  ").convert(report));
  } on Object catch (error, stackTrace) {
    stderr.writeln("catalog import/event soak failed: $error");
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

class _BenchmarkConfiguration {
  const _BenchmarkConfiguration({
    required this.projectCount,
    required this.sessionCount,
    required this.eventCount,
    required this.warmupCount,
    required this.readSampleCount,
  });

  final int projectCount;
  final int sessionCount;
  final int eventCount;
  final int warmupCount;
  final int readSampleCount;

  static _BenchmarkConfiguration parse({required List<String> arguments}) {
    final parser = ArgParser()
      ..addOption("projects", defaultsTo: "$_defaultProjectCount")
      ..addOption("sessions", defaultsTo: "$_defaultSessionCount")
      ..addOption("events", defaultsTo: "$_defaultEventCount")
      ..addOption("warmup", defaultsTo: "$_defaultWarmupCount")
      ..addOption("read-samples", defaultsTo: "$_defaultReadSampleCount");
    final parsed = parser.parse(arguments);
    final projectCount = int.tryParse(parsed.option("projects") ?? "");
    final sessionCount = int.tryParse(parsed.option("sessions") ?? "");
    final eventCount = int.tryParse(parsed.option("events") ?? "");
    final warmupCount = int.tryParse(parsed.option("warmup") ?? "");
    final readSampleCount = int.tryParse(parsed.option("read-samples") ?? "");
    if (projectCount == null || projectCount < 1) {
      throw const FormatException("--projects must be a positive integer");
    }
    if (sessionCount == null || sessionCount < projectCount) {
      throw const FormatException("--sessions must be an integer greater than or equal to --projects");
    }
    if (eventCount == null || eventCount < 1) {
      throw const FormatException("--events must be a positive integer");
    }
    if (warmupCount == null || warmupCount < 0) {
      throw const FormatException("--warmup must be a non-negative integer");
    }
    if (readSampleCount == null || readSampleCount < 1) {
      throw const FormatException("--read-samples must be a positive integer");
    }
    return _BenchmarkConfiguration(
      projectCount: projectCount,
      sessionCount: sessionCount,
      eventCount: eventCount,
      warmupCount: warmupCount,
      readSampleCount: readSampleCount,
    );
  }
}

class _CatalogImportEventSoak {
  const _CatalogImportEventSoak({required _BenchmarkConfiguration configuration}) : _configuration = configuration;

  final _BenchmarkConfiguration _configuration;

  Future<Map<String, Object?>> run() async {
    final temporaryDirectory = await Directory.systemTemp.createTemp("sesori-catalog-import-event-soak-");
    final databaseFile = File(p.join(temporaryDirectory.path, "benchmark.sqlite"));
    final releaseEnumeration = Completer<void>();
    final releaseWriter = Completer<void>();
    AppDatabase? database;
    SessionRepository? sessionRepository;
    _CountingSSEManager? sseManager;
    StreamSubscription<CatalogImportProgress>? importSubscription;
    Future<void>? heldWriter;
    _SchedulingLagProbe? schedulingProbe;
    _PeakRssSampler? rssSampler;

    try {
      database = AppDatabase.openFile(file: databaseFile);
      final sqliteVersion = await _sqliteVersion(database: database);
      final fixture = _fixture(rootDirectory: temporaryDirectory.path);
      await _seedLastCommittedCatalog(database: database, fixture: fixture);
      await _checkpoint(database: database);
      final databaseBytesBeforeImport = databaseFile.lengthSync();

      final plugin = _BenchmarkPlugin(
        launchDirectory: fixture.projectPaths.first,
        sessions: fixture.sessions,
        releaseEnumeration: releaseEnumeration,
      );
      final plugins = <String, BridgePluginApi>{plugin.id: plugin};
      final runtime = createBenchmarkPluginRuntime(plugins: plugins.values);
      final importRepository = CatalogImportRepository(
        runtime: runtime,
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        catalogHydrationsDao: database.catalogHydrationsDao,
        projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
      );
      sessionRepository = SessionRepository(
        runtime: runtime,
        bridgeDerivedProjectPluginIds: {plugin.id},
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
        pullRequestDao: database.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
        projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
        aggregateSourceDeadline: const Duration(seconds: 5),
      );
      final projectRepository = ProjectRepository(
        operationalPlugins: plugins,
        readDefaultEnabledPluginId: () => plugin.id,
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: _ExistingFilesystemApi(),
        gitCliApi: GitCliApi(
          processRunner: ProcessRunner(),
          gitPathExists: ({required String gitPath}) => false,
        ),
        projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
        aggregateSourceDeadline: const Duration(seconds: 5),
      );
      final eventTracker = SessionEventTracker(
        maxPendingEntriesPerPlugin: SessionEventTracker.defaultMaxPendingEntries,
      );
      final failureReporter = _BenchmarkFailureReporter();
      final eventService = SessionEventService(
        sessionRepository: sessionRepository,
        pluginRuntime: runtime,
        eventMapper: const SessionEventMapper(),
        eventTracker: eventTracker,
        failureReporter: failureReporter,
      );
      final bridgeEventMapper = BridgeEventMapper(failureReporter: failureReporter);
      sseManager = _CountingSSEManager(failureReporter: failureReporter);
      sseManager.subscribePath(1, "/global/event", _BenchmarkRelayClient());
      sseManager.unsubscribe(1);
      if (sseManager.pendingReplayCount != 1) {
        throw StateError("benchmark relay replay queue was not created");
      }

      final rssBefore = ProcessInfo.currentRss;
      final importRssSampler = _PeakRssSampler(initialRss: rssBefore)..start();
      rssSampler = importRssSampler;
      final importProgress = <CatalogImportProgress>[];
      final importCompleted = Completer<CatalogImportCompleted>();
      final importStopwatch = Stopwatch()..start();
      final publicationStopwatch = Stopwatch();
      importSubscription = importRepository
          .importCatalog(
            pluginId: plugin.id,
            control: CatalogImportControl(
              explicitImportRequested: false,
              hydrationMarkerRequested: true,
            ),
          )
          .listen(
            (progress) {
              importProgress.add(progress);
              importRssSampler.sample();
              if (progress is CatalogImportCommitting) publicationStopwatch.start();
              if (progress is CatalogImportCompleted && !importCompleted.isCompleted) {
                publicationStopwatch.stop();
                importStopwatch.stop();
                importCompleted.complete(progress);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!importCompleted.isCompleted) importCompleted.completeError(error, stackTrace);
            },
            onDone: () {
              if (!importCompleted.isCompleted) {
                importCompleted.completeError(StateError("catalog import ended without a completed status"));
              }
            },
          );
      await plugin.enumerationStarted.future;

      schedulingProbe = _SchedulingLagProbe()..start();
      final writerStarted = Completer<void>();
      heldWriter = database.transaction(() async {
        try {
          await database!.customStatement(
            "UPDATE projects_table SET updated_at = updated_at WHERE project_id = ?",
            <Object?>[fixture.projectPaths.first],
          );
          writerStarted.complete();
          await releaseWriter.future;
        } on Object catch (error, stackTrace) {
          if (!writerStarted.isCompleted) writerStarted.completeError(error, stackTrace);
          rethrow;
        }
      });
      await writerStarted.future;
      await schedulingProbe.firstSample;

      for (var index = 0; index < _configuration.warmupCount; index++) {
        await _readCatalog(
          projectRepository: projectRepository,
          sessionRepository: sessionRepository,
          sentinelProjectId: fixture.projectPaths.first,
        );
      }
      final readSamples = <int>[];
      for (var index = 0; index < _configuration.readSampleCount; index++) {
        final stopwatch = Stopwatch()..start();
        await _readCatalog(
          projectRepository: projectRepository,
          sessionRepository: sessionRepository,
          sentinelProjectId: fixture.projectPaths.first,
        );
        stopwatch.stop();
        readSamples.add(stopwatch.elapsedMicroseconds);
      }
      final readsCompletedWhileBlocked =
          !releaseEnumeration.isCompleted && !releaseWriter.isCompleted && !importCompleted.isCompleted;
      if (!readsCompletedWhileBlocked) {
        throw StateError("catalog reads did not complete while enumeration and a writer were held");
      }
      releaseWriter.complete();
      await heldWriter;
      heldWriter = null;

      await _waitForTimestampAfter(timestamp: plugin.enumerationStartedAt!);
      var translatedEvents = 0;
      for (var index = 0; index < _configuration.warmupCount; index++) {
        translatedEvents += await _projectMapAndEnqueue(
          eventService: eventService,
          bridgeEventMapper: bridgeEventMapper,
          sseManager: sseManager,
          fixture: fixture,
          title: "warmup-$index",
          updatedAt: _eventTimestamp + index,
        );
      }
      final eventSamples = <int>[];
      for (var index = 0; index < _configuration.eventCount; index++) {
        final stopwatch = Stopwatch()..start();
        translatedEvents += await _projectMapAndEnqueue(
          eventService: eventService,
          bridgeEventMapper: bridgeEventMapper,
          sseManager: sseManager,
          fixture: fixture,
          title: "sentinel-$index",
          updatedAt: _eventTimestamp + _configuration.warmupCount + index,
        );
        stopwatch.stop();
        eventSamples.add(stopwatch.elapsedMicroseconds);
      }
      final expectedTranslatedEvents = _configuration.warmupCount + _configuration.eventCount;
      if (translatedEvents != expectedTranslatedEvents || sseManager.enqueueCount != expectedTranslatedEvents) {
        throw StateError(
          "translated/enqueued $translatedEvents/${sseManager.enqueueCount} events; expected $expectedTranslatedEvents",
        );
      }

      releaseEnumeration.complete();
      final completion = await importCompleted.future;
      final rssAfter = importRssSampler.sample();
      importRssSampler.stop();
      rssSampler = null;
      final rssPeak = importRssSampler.peakRss;
      schedulingProbe.stop();
      await importSubscription.cancel();
      importSubscription = null;

      _verifyImportProgress(progress: importProgress, completion: completion);
      await _verifyFinalCatalog(
        database: database,
        fixture: fixture,
        plugin: plugin,
        eventTracker: eventTracker,
      );
      if (readSamples.isEmpty || eventSamples.isEmpty || schedulingProbe.samples.isEmpty) {
        throw StateError("latency, read, and scheduling sample sets must all be non-empty");
      }

      readSamples.sort();
      eventSamples.sort();
      final schedulingSamples = schedulingProbe.samples..sort();
      await _checkpoint(database: database);
      final databaseBytesAfterImport = databaseFile.lengthSync();
      final databaseSchemaVersion = database.schemaVersion;
      final report = <String, Object?>{
        "schemaVersion": 2,
        "benchmark": "catalog_import_event_soak",
        "generatedAt": DateTime.now().toUtc().toIso8601String(),
        "host": _hostMetadata(),
        "runtime": _runtimeMetadata(),
        "commit": _commitMetadata(),
        "fixture": {
          "pluginCount": 1,
          "capability": "bridge-derived-projects",
          "projectCount": _configuration.projectCount,
          "sessionCount": _configuration.sessionCount,
          "knownSessionEventCount": _configuration.eventCount,
          "warmupEventCount": _configuration.warmupCount,
          "catalogReadSampleCount": _configuration.readSampleCount,
          "projectionVersion": CatalogImportRepository.projectionVersion,
        },
        "database": {
          "engine": "sqlite",
          "engineVersion": sqliteVersion,
          "driftSchemaVersion": databaseSchemaVersion,
          "fileBacked": true,
          "temporary": true,
          "bytesBeforeImport": databaseBytesBeforeImport,
          "bytesAfterImport": databaseBytesAfterImport,
          "growthBytes": databaseBytesAfterImport - databaseBytesBeforeImport,
        },
        "measurement": {
          "clock": "Stopwatch",
          "unit": "microseconds",
          "percentileMethod": "nearest-rank",
          "hostThresholdsAsserted": false,
        },
        "latencyMicroseconds": {
          "catalogReadWhileEnumerationAndWriterBlocked": _percentiles(readSamples),
          "knownSessionEventProjectionMapAndEnqueue": _percentiles(eventSamples),
          "schedulingLag": _percentiles(schedulingSamples),
          "import": importStopwatch.elapsedMicroseconds,
          "publication": publicationStopwatch.elapsedMicroseconds,
        },
        "rssBytes": {
          "before": rssBefore,
          "peak": rssPeak,
          "after": rssAfter,
          "growth": rssPeak - rssBefore,
          "finalGrowth": rssAfter - rssBefore,
        },
        "import": {
          "completedCount": importProgress.whereType<CatalogImportCompleted>().length,
          "projectsImported": completion.projectsImported,
          "sessionsImported": completion.sessionsImported,
        },
        "events": {
          "translatedAndEnqueuedIncludingWarmup": translatedEvents,
          "pendingTrackerEntries": eventTracker.length,
        },
        "pluginCalls": {
          "importEnumerations": plugin.enumerationCalls,
          "catalogListReads": plugin.listReadCalls,
        },
        "invariants": {
          "catalogReadsCompletedWhileEnumerationAndWriterBlocked": readsCompletedWhileBlocked,
          "exactPluginBindings": true,
          "duplicatePluginBackendIdentities": 0,
          "hydrationMarkersV1": 1,
          "foreignKeyViolations": 0,
          "backendIdLeaks": 0,
          "sentinelSurvivedPublication": true,
        },
      };

      sseManager.stop();
      sseManager = null;
      await sessionRepository.dispose();
      sessionRepository = null;
      await database.close();
      database = null;
      return report;
    } finally {
      if (!releaseWriter.isCompleted) releaseWriter.complete();
      if (!releaseEnumeration.isCompleted) releaseEnumeration.complete();
      schedulingProbe?.stop();
      rssSampler?.stop();
      if (heldWriter case final writer?) {
        try {
          await writer;
        } on Object catch (error, stackTrace) {
          stderr.writeln("held benchmark writer failed during cleanup: $error");
          stderr.writeln(stackTrace);
        }
      }
      await importSubscription?.cancel();
      sseManager?.stop();
      if (sessionRepository != null) await sessionRepository.dispose();
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
          id: _backendSessionId(index),
          projectID: projectPath,
          directory: projectPath,
          parentID: null,
          title: index == 0 ? "stale-import-sentinel" : "Imported session $index",
          time: PluginSessionTime(
            created: _catalogTimestamp + index,
            updated: _catalogTimestamp + index + 1,
            archived: null,
          ),
        );
      },
      growable: false,
    );
    return (projectPaths: projectPaths, sessions: sessions);
  }

  Future<void> _seedLastCommittedCatalog({
    required AppDatabase database,
    required ({List<String> projectPaths, List<PluginSession> sessions}) fixture,
  }) async {
    await database.projectsDao.upsertProjectRows(
      rows: [
        for (var index = 0; index < fixture.projectPaths.length; index++)
          ProjectDto(
            projectId: fixture.projectPaths[index],
            path: fixture.projectPaths[index],
            hidden: false,
            baseBranch: null,
            displayName: "Project $index",
            createdAt: _catalogTimestamp + index,
            updatedAt: _catalogTimestamp + index,
            projectionUpdatedAt: _catalogTimestamp + index,
          ),
      ],
    );
    await database.sessionDao.upsertSessionRows(
      rows: [
        SessionDto(
          sessionId: _sentinelSessionId,
          backendSessionId: fixture.sessions.first.id,
          projectId: fixture.projectPaths.first,
          parentSessionId: null,
          directory: fixture.projectPaths.first,
          worktreePath: null,
          branchName: null,
          isDedicated: false,
          archivedAt: null,
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
          createdAt: _catalogTimestamp,
          updatedAt: _catalogTimestamp,
          projectionUpdatedAt: _catalogTimestamp,
          lastActivityAt: null,
          lastSeenAt: null,
          lastUserMessageAt: null,
          pluginId: _pluginId,
          title: null,
          catalogTitle: "last-committed-sentinel",
        ),
      ],
    );
  }

  Future<void> _readCatalog({
    required ProjectRepository projectRepository,
    required SessionRepository sessionRepository,
    required String sentinelProjectId,
  }) async {
    final projects = await projectRepository.getProjects();
    if (projects.length != _configuration.projectCount) {
      throw StateError("catalog read returned ${projects.length} projects; expected ${_configuration.projectCount}");
    }
    final sessions = await sessionRepository.getSessionsForProject(
      projectId: sentinelProjectId,
      start: null,
      limit: null,
    );
    if (sessions.length != 1 || sessions.single.id != _sentinelSessionId) {
      throw StateError("last-committed sentinel was not readable while import was blocked");
    }
  }

  Future<int> _projectMapAndEnqueue({
    required SessionEventService eventService,
    required BridgeEventMapper bridgeEventMapper,
    required _CountingSSEManager sseManager,
    required ({List<String> projectPaths, List<PluginSession> sessions}) fixture,
    required String title,
    required int updatedAt,
  }) async {
    final source = eventService.captureSource(
      pluginId: _pluginId,
      generation: 1,
      event: BridgeSseSessionUpdated(
        info: Session(
          branchName: null,
          id: fixture.sessions.first.id,
          pluginId: _pluginId,
          projectID: fixture.projectPaths.first,
          directory: fixture.projectPaths.first,
          parentID: null,
          title: title,
          time: SessionTime(
            created: _catalogTimestamp,
            updated: updatedAt,
            archived: null,
          ),
          pullRequest: null,
          promptDefaults: null,
        ).toJson(),
        titleChanged: false,
      ),
    );
    final normalized = await eventService.normalize(source: source);
    if (normalized.length != 1) {
      throw StateError("known-session input produced ${normalized.length} translated events; expected one");
    }
    final shared = bridgeEventMapper.map(normalized.single);
    if (shared == null) throw StateError("known-session event did not map to a shared event");
    final encoded = jsonEncode(shared.toJson());
    if (encoded.contains(fixture.sessions.first.id)) {
      throw StateError("shared event leaked backend session id ${fixture.sessions.first.id}");
    }
    sseManager.enqueueEvent(shared);
    return 1;
  }

  void _verifyImportProgress({
    required List<CatalogImportProgress> progress,
    required CatalogImportCompleted completion,
  }) {
    final completed = progress.whereType<CatalogImportCompleted>().toList(growable: false);
    if (completed.length != 1 || !identical(completed.single, completion)) {
      throw StateError("catalog import did not emit exactly one completed status");
    }
    if (completion.projectsImported != _configuration.projectCount ||
        completion.sessionsImported != _configuration.sessionCount) {
      throw StateError(
        "import completed with ${completion.projectsImported}/${completion.sessionsImported} projects/sessions; "
        "expected ${_configuration.projectCount}/${_configuration.sessionCount}",
      );
    }
  }

  Future<void> _verifyFinalCatalog({
    required AppDatabase database,
    required ({List<String> projectPaths, List<PluginSession> sessions}) fixture,
    required _BenchmarkPlugin plugin,
    required SessionEventTracker eventTracker,
  }) async {
    final projects = await database.projectsDao.getAllProjects();
    if (projects.length != _configuration.projectCount) {
      throw StateError("final catalog has ${projects.length} projects; expected ${_configuration.projectCount}");
    }
    final bindings = await database.sessionDao.getSessionsForPlugin(pluginId: plugin.id);
    if (bindings.length != _configuration.sessionCount) {
      throw StateError("final catalog has ${bindings.length} plugin bindings; expected ${_configuration.sessionCount}");
    }
    for (var index = 0; index < fixture.sessions.length; index++) {
      final expectedBackendId = fixture.sessions[index].id;
      final binding = bindings[expectedBackendId];
      if (binding == null || binding.pluginId != plugin.id) {
        throw StateError("missing exact plugin binding $plugin.id/$expectedBackendId");
      }
    }
    final allPluginIds = await database.customSelect("SELECT DISTINCT plugin_id FROM sessions_table").get();
    if (allPluginIds.length != 1 || allPluginIds.single.read<String>("plugin_id") != plugin.id) {
      throw StateError("final catalog contains a session binding for an unexpected plugin");
    }
    final duplicateBindings = await database
        .customSelect(
          "SELECT plugin_id, backend_session_id FROM sessions_table "
          "GROUP BY plugin_id, backend_session_id HAVING COUNT(*) > 1",
        )
        .get();
    if (duplicateBindings.isNotEmpty) {
      throw StateError("final catalog contains duplicate plugin/backend identities: ${duplicateBindings.first.data}");
    }
    final hydrations = await database
        .customSelect("SELECT plugin_id, projection_version FROM catalog_hydrations_table")
        .get();
    if (hydrations.length != 1 ||
        hydrations.single.read<String>("plugin_id") != plugin.id ||
        hydrations.single.read<int>("projection_version") != CatalogImportRepository.projectionVersion) {
      throw StateError("catalog import did not leave exactly one v1 hydration marker");
    }
    final foreignKeyViolations = await database.customSelect("PRAGMA foreign_key_check").get();
    if (foreignKeyViolations.isNotEmpty) {
      throw StateError("catalog import left foreign key violations: ${foreignKeyViolations.first.data}");
    }
    final sentinel = await database.sessionDao.getSession(sessionId: _sentinelSessionId);
    final finalTitle = "sentinel-${_configuration.eventCount - 1}";
    final finalUpdatedAt = _eventTimestamp + _configuration.warmupCount + _configuration.eventCount - 1;
    if (sentinel?.backendSessionId != fixture.sessions.first.id ||
        sentinel?.catalogTitle != finalTitle ||
        sentinel?.updatedAt != finalUpdatedAt ||
        sentinel!.projectionUpdatedAt <= plugin.enumerationStartedAt!) {
      throw StateError("post-import-start sentinel projection did not survive publication with its final title/time");
    }
    if (eventTracker.length != 0) {
      throw StateError("session event tracker retained ${eventTracker.length} pending entries");
    }
    if (plugin.enumerationCalls != 1) {
      throw StateError("catalog import enumerated the plugin ${plugin.enumerationCalls} times; expected once");
    }
    if (plugin.listReadCalls != 0) {
      throw StateError("database-backed catalog reads made ${plugin.listReadCalls} plugin list calls");
    }
  }

  Future<void> _waitForTimestampAfter({required int timestamp}) async {
    while (DateTime.now().millisecondsSinceEpoch <= timestamp) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  Future<void> _checkpoint({required AppDatabase database}) async {
    await database.customSelect("PRAGMA wal_checkpoint(TRUNCATE)").get();
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

class _PeakRssSampler {
  _PeakRssSampler({required int initialRss}) : _peakRss = initialRss;

  int _peakRss;
  Timer? _timer;

  int get peakRss => _peakRss;

  void start() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 1), (_) => sample());
  }

  int sample() {
    final rss = ProcessInfo.currentRss;
    if (rss > _peakRss) _peakRss = rss;
    return rss;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

String _backendSessionId(int index) => "backend-${index.toString().padLeft(6, "0")}";

Map<String, int> _percentiles(List<int> sortedSamples) {
  if (sortedSamples.isEmpty) throw ArgumentError.value(sortedSamples, "sortedSamples", "must not be empty");
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

class _SchedulingLagProbe {
  final List<int> samples = <int>[];
  final Completer<void> _firstSample = Completer<void>();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _running = false;

  Future<void> get firstSample => _firstSample.future;

  void start() {
    if (_running) return;
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
      if (!_firstSample.isCompleted) _firstSample.complete();
      _schedule();
    });
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _stopwatch.stop();
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
  int? enumerationStartedAt;
  int enumerationCalls = 0;
  int listReadCalls = 0;

  @override
  String get id => _pluginId;

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    enumerationCalls++;
    enumerationStartedAt = DateTime.now().millisecondsSinceEpoch;
    if (!enumerationStarted.isCompleted) enumerationStarted.complete();
    await releaseEnumeration.future;
    return sessions;
  }

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) {
    listReadCalls++;
    return Future<List<PluginSession>>.error(StateError("catalog read unexpectedly called plugin.getSessions"));
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) {
    listReadCalls++;
    return Future<List<PluginSession>>.error(StateError("catalog read unexpectedly called plugin.getChildSessions"));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingSSEManager extends SSEManager {
  _CountingSSEManager({required super.failureReporter})
    : super(
        replayWindow: const Duration(minutes: 1),
        onBytesSent: (_) {},
      );

  int enqueueCount = 0;

  @override
  void enqueueEvent(SesoriSseEvent event) {
    enqueueCount++;
    super.enqueueEvent(event);
  }
}

class _ExistingFilesystemApi implements FilesystemApi {
  @override
  bool directoryExists(String path) => true;

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
