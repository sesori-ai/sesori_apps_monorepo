import "dart:convert";
import "dart:io";

import "package:grok_plugin/src/api/grok_session_store_api.dart";
import "package:grok_plugin/src/repositories/grok_session_catalog_repository.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

const String _cwd = "/tmp/synthetic-project";
const String _root = "01a00000-0000-7000-8000-00000000000a";
const String _childA = "01a00000-0000-7000-8000-00000000000b";
const String _childB = "01a00000-0000-7000-8000-00000000000c";

/// Mirrors the 1.0.5 layout verified from a live run:
/// `<sessions>/<percent-encoded cwd>/<session id>/{summary.json, updates.jsonl}`.
void main() {
  late Directory sessions;
  late GrokSessionCatalogRepository repository;

  String sessionDir(String id) => p.join(sessions.path, Uri.encodeComponent(_cwd), id);

  void writeSummary(String id, Map<String, dynamic> summary) {
    File(p.join(sessionDir(id), "summary.json"))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(summary));
  }

  Map<String, dynamic> spawnedLine(String childId, String description) => {
    "timestamp": 1788356687,
    "method": "_x.ai/session/update",
    "params": {
      "sessionId": _root,
      "update": {
        "sessionUpdate": "subagent_spawned",
        "subagent_id": childId,
        "parent_session_id": _root,
        "child_session_id": childId,
        "subagent_type": "general-purpose",
        "description": description,
        "model": "synthetic:model-alpha",
      },
    },
  };

  void writeUpdates(String id, List<Object> lines) {
    File(p.join(sessionDir(id), "updates.jsonl"))
      ..createSync(recursive: true)
      ..writeAsStringSync(lines.map((line) => line is String ? line : jsonEncode(line)).join("\n"));
  }

  setUp(() {
    sessions = Directory.systemTemp.createTempSync("grok-sessions-");
    repository = GrokSessionCatalogRepository(
      api: GrokSessionStoreApi(sessionsRoot: sessions.path, pluginId: "grok-test"),
    );
    writeSummary(_root, {
      "info": {"id": _root, "cwd": _cwd},
      "generated_title": "Root",
    });
    writeSummary(_childA, {
      "info": {"id": _childA, "cwd": _cwd},
      "session_kind": "subagent",
      "agent_name": "general-purpose",
      "generated_title": "Child A title",
      "created_at": "2026-09-02T13:44:47.357507Z",
      "updated_at": "2026-09-02T13:46:25.056022Z",
    });
    writeUpdates(_root, [
      {
        "timestamp": 1,
        "method": "_x.ai/session/update",
        "params": {
          "sessionId": _root,
          "update": {"sessionUpdate": "turn_completed"},
        },
      },
      spawnedLine(_childA, "Child A"),
      spawnedLine(_childB, "Child B"),
      spawnedLine(_childA, "Child A again"),
    ]);
  });

  tearDown(() => sessions.deleteSync(recursive: true));

  test("children come from the root's persisted spawn records, enriched by their summaries", () {
    final children = repository.childSessions(cwd: _cwd, rootId: _root);
    expect(children.map((session) => session.id), [_childA, _childB], reason: "spawn order, deduplicated");
    final a = children.first;
    expect(a.parentID, _root);
    expect(a.directory, _cwd);
    expect(a.projectID, _cwd);
    expect(a.title, "Child A title");
    expect(a.time?.created, DateTime.parse("2026-09-02T13:44:47.357507Z").millisecondsSinceEpoch);
    expect(a.time?.updated, DateTime.parse("2026-09-02T13:46:25.056022Z").millisecondsSinceEpoch);
    final b = children.last;
    expect(b.title, "Child B", reason: "no summary yet: the spawn description stands in");
    expect(b.time, isNull);
  });

  test("one malformed update line is skipped without hiding valid spawn records", () {
    writeUpdates(_root, [
      spawnedLine(_childA, "Child A"),
      {"method": "foreign/update", "params": "not a Grok session notification"},
      "not json at all",
      spawnedLine(_childB, "Child B"),
    ]);
    expect(repository.childSessions(cwd: _cwd, rootId: _root).map((session) => session.id), [_childA, _childB]);
  });

  test("parentOf resolves a persisted sub-agent to its root and nothing else", () {
    expect(repository.parentOf(cwd: _cwd, sessionId: _childA), _root);
    expect(
      repository.parentOf(cwd: _cwd, sessionId: _root),
      isNull,
      reason: "not a subagent",
    );
    expect(repository.parentOf(cwd: _cwd, sessionId: "missing"), isNull);
    writeSummary(_childB, {
      "info": {"id": _childB, "cwd": _cwd},
      "session_kind": "subagent",
    });
    expect(repository.parentOf(cwd: _cwd, sessionId: _childB), _root);
  });

  test("an unknown project or a missing store reads as empty", () {
    expect(repository.childSessions(cwd: "/elsewhere", rootId: _root), isEmpty);
    expect(repository.parentOf(cwd: "/elsewhere", sessionId: _childA), isNull);
    final homeless = GrokSessionCatalogRepository(
      api: GrokSessionStoreApi(sessionsRoot: null, pluginId: "grok-test"),
    );
    expect(homeless.childSessions(cwd: _cwd, rootId: _root), isEmpty);
  });

  test("malformed summaries and unreadable update files propagate", () {
    File(p.join(sessionDir(_childA), "summary.json")).writeAsStringSync("{broken");
    expect(() => repository.childSessions(cwd: _cwd, rootId: _root), throwsFormatException);
    expect(() => repository.parentOf(cwd: _cwd, sessionId: _childA), throwsFormatException);

    writeSummary(_childA, {
      "info": {"id": _childA, "cwd": _cwd},
      "session_kind": "subagent",
    });
    File(p.join(sessionDir(_root), "updates.jsonl")).writeAsBytesSync([0xff]);
    expect(() => repository.childSessions(cwd: _cwd, rootId: _root), throwsA(isA<FileSystemException>()));
  });

  test("resolves several persisted directories with one tree scan", () {
    const otherCwd = "/tmp/other-synthetic-project";
    const otherRoot = "01a00000-0000-7000-8000-00000000000d";
    File(p.join(sessions.path, Uri.encodeComponent(otherCwd), otherRoot, "summary.json"))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          "info": {"id": otherRoot, "cwd": otherCwd},
        }),
      );
    final api = _CountingGrokSessionStoreApi(sessionsRoot: sessions.path);
    final indexedRepository = GrokSessionCatalogRepository(api: api);

    expect(
      indexedRepository.persistedDirectoriesForSessions(sessionIds: {_root, otherRoot, "missing"}),
      {_root: _cwd, otherRoot: otherCwd},
    );
    expect(api.projectListCount, 1);
    expect(api.sessionListCounts, {_cwd: 1, otherCwd: 1});
  });

  test("resolves persisted directories and uses updated time when created time is absent", () {
    writeSummary(_childA, {
      "info": {"id": _childA, "cwd": _cwd},
      "session_kind": "subagent",
      "updated_at": "2026-09-02T13:46:25.056022Z",
    });
    expect(repository.persistedDirectoryForSession(sessionId: _root), _cwd);
    expect(repository.persistedDirectoryForSession(sessionId: "missing"), isNull);
    final time = repository.childSessions(cwd: _cwd, rootId: _root).first.time!;
    expect(time.created, DateTime.parse("2026-09-02T13:46:25.056022Z").millisecondsSinceEpoch);
    expect(time.updated, time.created);
  });

  test("session ids cannot escape their persisted project directory", () {
    final api = GrokSessionStoreApi(sessionsRoot: sessions.path, pluginId: "grok-test");
    expect(() => api.readSummary(cwd: _cwd, sessionId: "../$_childA"), throwsArgumentError);
    expect(() => api.readSpawnRecords(cwd: _cwd, sessionId: ".."), throwsArgumentError);
  });

  test("the store resolves under the foundation-provided home directory", () {
    final api = GrokSessionStoreApi.forHome(environment: {"HOME": sessions.path}, pluginId: "grok-test");
    expect(api.sessionsRoot, p.join(sessions.path, ".grok", "sessions"));
    expect(GrokSessionStoreApi.forHome(environment: const {}, pluginId: "grok-test").sessionsRoot, isNull);
    expect(GrokSessionStoreApi.encodeCwd(cwd: "/tmp/grok-probe/project-spawn"), "%2Ftmp%2Fgrok-probe%2Fproject-spawn");
  });
}

final class _CountingGrokSessionStoreApi({
  required super.sessionsRoot,
  super.pluginId = "grok-test",
}) extends GrokSessionStoreApi {
  int projectListCount = 0;
  final Map<String, int> sessionListCounts = {};

  @override
  List<String> listProjectDirectories() {
    projectListCount++;
    return super.listProjectDirectories();
  }

  @override
  List<String> listSessionIds({required String cwd}) {
    sessionListCounts.update(cwd, (count) => count + 1, ifAbsent: () => 1);
    return super.listSessionIds(cwd: cwd);
  }
}
