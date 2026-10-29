// Times the Claude transcript scanner and the bridge import over a fixture
// written by `claude_session_fixture.dart`. Needs no Claude login.
//
//   dart run tool/benchmarks/claude_catalog_benchmark.dart --fixture /tmp/claude-10k
//
// Measures, in one process:
// - two catalog scans through the plugin's production isolate path;
// - two imports into a temporary bridge database: rows submitted for upsert,
//   progress events, and backend-activity entries handed to the chat-history
//   listener;
// - the `/sessions` response body for every project, built by the route's own
//   repository read and encoded as the relay sends it.

import "dart:convert";
import "dart:ffi" show Abi;
import "dart:io";

import "package:args/args.dart";
import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/daos/projects_dao.dart";
import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/projects_table.dart";
import "package:sesori_bridge/src/api/database/tables/session_table.dart";
import "package:sesori_bridge/src/repositories/catalog_import_repository.dart";
import "package:sesori_bridge/src/repositories/models/catalog_import_control.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "benchmark_plugin_runtime.dart";

const _pluginId = "claude";

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()..addOption("fixture", help: "CLAUDE_CONFIG_DIR written by claude_session_fixture.dart");
  final fixture = parser.parse(arguments).option("fixture");
  if (fixture == null || !Directory(p.join(fixture, "projects")).existsSync()) {
    stderr.writeln("usage: claude_catalog_benchmark.dart --fixture <dir>\n${parser.usage}");
    exitCode = 64;
    return;
  }
  try {
    final report = await _run(fixture: fixture);
    stdout.writeln(const JsonEncoder.withIndent("  ").convert(report));
  } on Object catch (error, stackTrace) {
    stderr.writeln("claude catalog benchmark failed: $error");
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

Future<Map<String, Object?>> _run({required String fixture}) async {
  final catalog = ClaudeTranscriptCatalogRepository(
    transcriptApi: ClaudeTranscriptApi(environment: {"CLAUDE_CONFIG_DIR": fixture}),
  );

  final scans = <Map<String, Object?>>[];
  for (var scan = 0; scan < 2; scan++) {
    final stopwatch = Stopwatch()..start();
    final records = await catalog.listSessionRecordsInIsolate();
    stopwatch.stop();
    scans.add({
      "milliseconds": stopwatch.elapsedMilliseconds,
      "roots": records.where((record) => record.parentId == null).length,
      "children": records.where((record) => record.parentId != null).length,
      "titled": records.where((record) => record.title != null).length,
    });
  }

  final temporaryDirectory = await Directory.systemTemp.createTemp("sesori-claude-catalog-");
  final database = AppDatabase.openFile(file: File(p.join(temporaryDirectory.path, "benchmark.sqlite")));
  try {
    final runtime = createBenchmarkPluginRuntime(plugins: [_ClaudeCatalogPlugin(catalog: catalog)]);
    final sessionDao = _CountingSessionDao(database);
    final projectsDao = _CountingProjectsDao(database);
    final importer = CatalogImportRepository(
      runtime: runtime,
      projectsDao: projectsDao,
      sessionDao: sessionDao,
      catalogHydrationsDao: database.catalogHydrationsDao,
      projectCatalogIdentityCalculator: ProjectCatalogIdentityCalculator(
        scratchRoot: "/scratch",
        pathContext: p.context,
      ),
    );
    var activityEntries = 0;
    final activitySubscription = importer.backendActivity.listen((batch) => activityEntries += batch.length);

    final imports = <Map<String, Object?>>[];
    for (var run = 0; run < 2; run++) {
      sessionDao.rowsWritten = 0;
      projectsDao.rowsWritten = 0;
      activityEntries = 0;
      final events = <String, int>{};
      final stopwatch = Stopwatch()..start();
      await for (final progress in importer.importCatalog(
        pluginId: _pluginId,
        control: CatalogImportControl(rescanRequested: run > 0, hydrationMarkerRequested: true),
      )) {
        events.update(progress.runtimeType.toString(), (count) => count + 1, ifAbsent: () => 1);
      }
      stopwatch.stop();
      imports.add({
        "kind": run == 0 ? "first import" : "rescan",
        "milliseconds": stopwatch.elapsedMilliseconds,
        "sessionRowsWritten": sessionDao.rowsWritten,
        "projectRowsWritten": projectsDao.rowsWritten,
        "progressEvents": events,
        "backendActivityEntries": activityEntries,
      });
    }
    await activitySubscription.cancel();
    await importer.dispose();

    final sessions = SessionRepository(
      runtime: runtime,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      unseenCalculator: const SessionUnseenCalculator(),
      projectCatalogIdentityCalculator: ProjectCatalogIdentityCalculator(
        scratchRoot: "/scratch",
        pathContext: p.context,
      ),
      aggregateSourceDeadline: const Duration(seconds: 5),
    );
    var totalBytes = 0;
    var largest = (bytes: 0, sessions: 0, milliseconds: 0);
    for (final project in await database.projectsDao.getAllProjects()) {
      final stopwatch = Stopwatch()..start();
      final items = await sessions.getSessionsForProject(projectId: project.projectId, start: null, limit: null);
      // The enrichment the route adds; no fixture session has a continuation.
      final enriched = [
        for (final session in items)
          session.copyWith(
            autoContinuation: const SessionAutoContinuationView(
              enabled: false,
              availability: AutoContinuationAvailability.conditional,
              status: SessionAutoContinuationStatus.idle(),
            ),
          ),
      ];
      final bytes = utf8.encode(jsonEncode(SessionListResponse(items: enriched).toJson())).length;
      stopwatch.stop();
      totalBytes += bytes;
      if (bytes > largest.bytes) {
        largest = (bytes: bytes, sessions: items.length, milliseconds: stopwatch.elapsedMilliseconds);
      }
    }
    await sessions.dispose();

    return {
      "benchmark": "claude_catalog_benchmark",
      "generatedAt": DateTime.now().toUtc().toIso8601String(),
      "host": {
        "operatingSystemVersion": Platform.operatingSystemVersion,
        "architecture": Abi.current().toString(),
        "logicalProcessors": Platform.numberOfProcessors,
      },
      "dartVersion": Platform.version,
      "scans": scans,
      "imports": imports,
      "sessionsRoute": {
        "totalBytes": totalBytes,
        "largestProjectBytes": largest.bytes,
        "largestProjectSessions": largest.sessions,
        "largestProjectReadAndEncodeMilliseconds": largest.milliseconds,
      },
    };
  } finally {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  }
}

/// Exposes the real Claude catalog as the bridge-derived plugin the import
/// reads; nothing else of the plugin is reached.
class _ClaudeCatalogPlugin({required final ClaudeTranscriptCatalogRepository _catalog})
    implements BridgeDerivedProjectsPluginApi {
  @override
  String get id => _pluginId;

  @override
  String get launchDirectory => "/Users/fixture/workspace/project-00";

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) =>
      _catalog.listAllSessions(knownDirectories: knownDirectories);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingSessionDao(super.attachedDatabase) extends SessionDao {
  int rowsWritten = 0;

  @override
  Future<void> upsertSessionRows({required List<SessionDto> rows}) {
    rowsWritten += rows.length;
    return super.upsertSessionRows(rows: rows);
  }
}

class _CountingProjectsDao(super.attachedDatabase) extends ProjectsDao {
  int rowsWritten = 0;

  @override
  Future<void> upsertProjectRows({required List<ProjectDto> rows}) {
    rowsWritten += rows.length;
    return super.upsertProjectRows(rows: rows);
  }
}
