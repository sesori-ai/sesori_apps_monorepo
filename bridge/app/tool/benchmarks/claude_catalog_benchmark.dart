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
//   repository read and encoded as the relay sends it;
// - `/sessions/page` across all projects: the route's repository read,
//   enrichment and encoding for a first page, a deep page, a counts-only
//   request, a search and the Unread chip (best of five runs each).

import "dart:convert";
import "dart:ffi" show Abi;
import "dart:io";

import "package:args/args.dart";
import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/daos/projects_dao.dart";
import "package:sesori_bridge/src/api/database/daos/session_continuation_dao.dart";
import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/projects_table.dart";
import "package:sesori_bridge/src/api/database/tables/session_table.dart";
import "package:sesori_bridge/src/repositories/catalog_import_repository.dart";
import "package:sesori_bridge/src/repositories/models/catalog_import_control.dart";
import "package:sesori_bridge/src/repositories/models/session_page_cursor.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:sesori_bridge/src/repositories/session_continuation_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/services/session_view_service.dart";
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
  var records = const <ClaudeSessionRecord>[];
  for (var scan = 0; scan < 2; scan++) {
    final stopwatch = Stopwatch()..start();
    records = await catalog.listSessionRecordsInIsolate();
    stopwatch.stop();
    scans.add({
      "milliseconds": stopwatch.elapsedMilliseconds,
      "roots": records.where((record) => record.parentId == null).length,
      "children": records.where((record) => record.parentId != null).length,
      "titled": records.where((record) => record.title != null).length,
    });
  }
  // A directory the fixture really holds, so the launch-directory seed adds no
  // extra empty project whatever `--workspace` generated the fixture.
  final launchDirectory = records.firstOrNull?.cwd;
  if (launchDirectory == null) throw StateError("fixture $fixture holds no Claude sessions");

  final temporaryDirectory = await Directory.systemTemp.createTemp("sesori-claude-catalog-");
  final database = AppDatabase.openFile(file: File(p.join(temporaryDirectory.path, "benchmark.sqlite")));
  try {
    final plugin = _ClaudeCatalogPlugin(catalog: catalog, launchDirectory: launchDirectory);
    final runtime = _ClaudeBenchmarkRuntime(plugins: {plugin.id: plugin});
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
    final sessionViews = SessionViewService(
      sessions: sessions,
      continuations: SessionContinuationRepository(
        dao: SessionContinuationDao(database: database),
        runtime: runtime,
      ),
      resetBuffer: const Duration(minutes: 2),
    );
    var totalBytes = 0;
    var largest = (bytes: 0, sessions: 0, milliseconds: 0);
    for (final project in await database.projectsDao.getAllProjects()) {
      final stopwatch = Stopwatch()..start();
      // The same read and enrichment as `GetSessionsHandler`.
      final items = await sessionViews.enrichMany(
        sessions: await sessions.getSessionsForProject(projectId: project.projectId, start: null, limit: null),
      );
      final bytes = utf8.encode(jsonEncode(SessionListResponse(items: items).toJson())).length;
      stopwatch.stop();
      totalBytes += bytes;
      if (bytes > largest.bytes) {
        largest = (bytes: bytes, sessions: items.length, milliseconds: stopwatch.elapsedMilliseconds);
      }
    }
    final pageRoute = await _timeSessionPages(sessions: sessions, sessionViews: sessionViews);
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
      "sessionsPageRoute": pageRoute,
    };
  } finally {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  }
}

/// Best-of-five milliseconds for `/sessions/page` requests, read, enriched and
/// encoded as `GetSessionPageHandler` does.
Future<Map<String, Object?>> _timeSessionPages({
  required SessionRepository sessions,
  required SessionViewService sessionViews,
}) async {
  Future<({int microseconds, SessionPage page, int bytes})> timePage({
    required SessionPageFilter filter,
    required String? query,
    required SessionPageCursor? cursor,
    required int limit,
  }) async {
    ({int microseconds, SessionPage page, int bytes})? best;
    for (var run = 0; run < 5; run++) {
      final stopwatch = Stopwatch()..start();
      final page = await sessions.getSessionPage(
        mode: SessionPageMode.active,
        projectId: null,
        query: query,
        filter: filter,
        cursor: cursor,
        limit: limit,
      );
      final response = SessionPageResponse(
        items: await sessionViews.enrichMany(sessions: page.items),
        nextCursor: page.nextCursor?.encode(),
        counts: page.counts,
      );
      final bytes = utf8.encode(jsonEncode(response.toJson())).length;
      stopwatch.stop();
      if (best == null || stopwatch.elapsedMicroseconds < best.microseconds) {
        best = (microseconds: stopwatch.elapsedMicroseconds, page: page, bytes: bytes);
      }
    }
    return best ?? (throw StateError("no runs"));
  }

  Map<String, Object?> report(({int microseconds, SessionPage page, int bytes}) result) => {
    "milliseconds": result.microseconds / 1000,
    "items": result.page.items.length,
    "bytes": result.bytes,
    "counts": result.page.counts.toJson(),
  };

  final first = await timePage(filter: SessionPageFilter.all, query: null, cursor: null, limit: 200);
  var cursor = first.page.nextCursor;
  // Walk 20 pages in, so the deep page starts after 4,000 rows.
  for (var index = 0; index < 19 && cursor != null; index++) {
    cursor = (await sessions.getSessionPage(
      mode: SessionPageMode.active,
      projectId: null,
      query: null,
      filter: SessionPageFilter.all,
      cursor: cursor,
      limit: 200,
    )).nextCursor;
  }
  return {
    "firstPage": report(first),
    "page21": report(await timePage(filter: SessionPageFilter.all, query: null, cursor: cursor, limit: 200)),
    "countsOnly": report(await timePage(filter: SessionPageFilter.all, query: null, cursor: null, limit: 0)),
    "searchTwoWords": report(
      await timePage(filter: SessionPageFilter.all, query: "fix test", cursor: null, limit: 200),
    ),
    "unreadChip": report(await timePage(filter: SessionPageFilter.unread, query: null, cursor: null, limit: 200)),
  };
}

/// Exposes the real Claude catalog as the bridge-derived plugin the import
/// reads; nothing else of the plugin is reached.
class _ClaudeCatalogPlugin({
  required final ClaudeTranscriptCatalogRepository _catalog,
  @override required final String launchDirectory,
}) implements BridgeDerivedProjectsPluginApi {
  @override
  String get id => _pluginId;

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) =>
      _catalog.listAllSessions(knownDirectories: knownDirectories);

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Reports Claude's quota support as its descriptor does, so the enriched
/// `/sessions` body matches the real route's.
class _ClaudeBenchmarkRuntime({required super.plugins}) extends BenchmarkPluginRuntime {
  @override
  PluginQuotaReportingSupport quotaReportingSupport({required String pluginId}) =>
      PluginQuotaReportingSupport.conditional;
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
