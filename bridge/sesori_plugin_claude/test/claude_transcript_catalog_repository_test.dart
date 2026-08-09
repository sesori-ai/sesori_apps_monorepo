import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

void main() {
  group("ClaudeTranscriptCatalogRepository", () {
    late Directory claudeHome;
    late ClaudeTranscriptCatalogRepository catalog;

    setUp(() {
      claudeHome = Directory.systemTemp.createTempSync("claude-home-");
      catalog = ClaudeTranscriptCatalogRepository(
        transcriptApi: ClaudeTranscriptApi(environment: {"CLAUDE_CONFIG_DIR": claudeHome.path}),
      );
    });

    tearDown(() {
      try {
        claudeHome.deleteSync(recursive: true);
      } on Object {
        // Best-effort cleanup.
      }
    });

    test("builds a session from a transcript header", () {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha", title: "Refactor the parser", branch: "main");

      final record = catalog.listSessionRecords().single;

      expect(record.id, _sessionA);
      expect(record.cwd, "/work/alpha");
      expect(record.title, "Refactor the parser");
      expect(record.gitBranch, "main");
      expect(record.cliVersion, "2.1.221");
      expect(record.createdAt, DateTime.utc(2026, 8, 4, 10));
      expect(record.updatedAt, isNotNull);
    });

    test("skips subagent transcripts, which outnumber sessions on disk", () {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "agent-aristotle-plan-5bfd2a36f892f25b.jsonl",
        records: [_userRecord(_sessionA, cwd: "/work/alpha", isSidechain: true)],
      );

      expect(catalog.listSessionRecords().map((record) => record.id), [_sessionA]);
    });

    test("skips a UUID-named transcript that holds only subagent records", () {
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          _userRecord(_sessionA, cwd: "/work/alpha", isSidechain: true),
          _userRecord(_sessionA, cwd: "/work/alpha", isSidechain: true),
        ],
      );

      expect(catalog.listSessionRecords(), isEmpty);
    });

    test("skips a transcript whose records claim a different session", () {
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [_userRecord(_sessionB, cwd: "/work/alpha")],
      );

      expect(catalog.listSessionRecords(), isEmpty);
    });

    test("accepts records without a session id because the filename is authoritative", () {
      final record = _userRecord(_sessionA, cwd: "/work/alpha")..remove("sessionId");
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [record],
      );

      expect(catalog.listSessionRecords().single.cwd, "/work/alpha");
    });

    test("does not borrow metadata from records for another session", () {
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          _userRecord(_sessionB, cwd: "/work/wrong"),
          _userRecord(_sessionA, cwd: "/work/alpha"),
          {"type": "ai-title", "aiTitle": "Wrong title", "sessionId": _sessionB},
          {"type": "ai-title", "aiTitle": "Right title", "sessionId": _sessionA},
        ],
      );

      final record = catalog.listSessionRecords().single;

      expect(record.cwd, "/work/alpha");
      expect(record.title, "Right title");
    });

    test("skips a transcript with no working directory to attribute it to", () {
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          {"type": "queue-operation", "sessionId": _sessionA, "operation": "enqueue"},
        ],
      );

      expect(catalog.listSessionRecords(), isEmpty);
    });

    test("leaves a session untitled when the CLI wrote no title", () {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");

      expect(catalog.listSessionRecords().single.title, isNull);
    });

    test("treats a blank title as untitled", () {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha", title: "   ");

      expect(catalog.listSessionRecords().single.title, isNull);
    });

    test("orders sessions newest first with undated ones last", () async {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha", timestamp: "2026-08-01T10:00:00.000Z");
      _writeSession(claudeHome, id: _sessionB, cwd: "/work/alpha", timestamp: "2026-08-03T10:00:00.000Z");
      _setModified(claudeHome, id: _sessionA, to: DateTime.utc(2026, 8, 1, 10));
      _setModified(claudeHome, id: _sessionB, to: DateTime.utc(2026, 8, 3, 10));

      expect(catalog.listSessionRecords().map((record) => record.id), [_sessionB, _sessionA]);
    });

    test("maps a session onto its normalized project directory", () async {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha/../alpha", title: "Alpha");

      final session = (await catalog.listAllSessions(knownDirectories: const {})).single;

      expect(session.id, _sessionA);
      expect(session.directory, "/work/alpha");
      expect(session.projectID, session.directory);
      expect(session.parentID, isNull);
      expect(session.title, "Alpha");
      expect(session.time?.created, DateTime.utc(2026, 8, 4, 10).millisecondsSinceEpoch);
      expect(session.time?.archived, isNull);
    });

    test("uses transcript mtime when the record creation time is unavailable", () async {
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          {
            "type": "user",
            "sessionId": _sessionA,
            "cwd": "/work/alpha",
            "isSidechain": false,
          },
        ],
      );
      final modified = DateTime.utc(2026, 8, 5, 12);
      _setModified(claudeHome, id: _sessionA, to: modified);

      final session = (await catalog.listAllSessions(knownDirectories: const {})).single;

      expect(session.time?.created, modified.millisecondsSinceEpoch);
      expect(session.time?.updated, modified.millisecondsSinceEpoch);
    });

    test("filters sessions to one project, normalizing the requested id", () async {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha", project: "-work-alpha");
      _writeSession(claudeHome, id: _sessionB, cwd: "/work/beta", project: "-work-beta");

      final alpha = await catalog.getSessions(projectId: "/work/alpha/", start: null, limit: null);

      expect(alpha.map((session) => session.id), [_sessionA]);
    });

    test("paginates within a project", () async {
      for (var i = 0; i < 5; i++) {
        _writeSession(
          claudeHome,
          id: _indexedSessionId(i),
          cwd: "/work/alpha",
          timestamp: "2026-08-0${i + 1}T10:00:00.000Z",
        );
        _setModified(claudeHome, id: _indexedSessionId(i), to: DateTime.utc(2026, 8, i + 1, 10));
      }

      final page = await catalog.getSessions(projectId: "/work/alpha", start: 1, limit: 2);

      expect(page.map((session) => session.id), [_indexedSessionId(3), _indexedSessionId(2)]);
      expect(await catalog.getSessions(projectId: "/work/alpha", start: 99, limit: 2), isEmpty);
      expect(await catalog.getSessions(projectId: "/work/alpha", start: null, limit: 99), hasLength(5));
    });

    test("resolves a transcript path by session id without reading it", () {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");

      expect(p.basename(catalog.findTranscriptPath(sessionId: _sessionA)!), "$_sessionA.jsonl");
      expect(catalog.findTranscriptPath(sessionId: _sessionB), isNull);
      expect(catalog.findSessionById(sessionId: _sessionA)?.cwd, "/work/alpha");
      expect(catalog.findSessionById(sessionId: _sessionB), isNull);
    });

    test("deletes a session's transcript and reports a missing one as not deleted", () {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");

      expect(catalog.deleteSession(sessionId: _sessionA), isTrue);
      expect(catalog.listSessionRecords(), isEmpty);
      expect(catalog.deleteSession(sessionId: _sessionA), isFalse);
    });

    test("reports no sessions when no home resolves", () {
      final catalog = ClaudeTranscriptCatalogRepository(
        transcriptApi: ClaudeTranscriptApi(environment: const {}),
      );

      expect(catalog.listSessionRecords(), isEmpty);
    });

    test("surfaces transcript enumeration failures", () {
      final catalog = ClaudeTranscriptCatalogRepository(
        transcriptApi: _ThrowingTranscriptApi(),
      );

      expect(catalog.listSessionRecords, throwsA(isA<FileSystemException>()));
    });

    test("enumerates off the main isolate", () async {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");

      expect((await catalog.listSessionRecordsInIsolate()).map((record) => record.id), [_sessionA]);
    });
  });
}

const String _sessionA = "11111111-2222-4333-8444-555555555555";
const String _sessionB = "66666666-7777-4888-8999-aaaaaaaaaaaa";

String _indexedSessionId(int index) => "0000000$index-2222-4333-8444-555555555555";

Map<String, Object?> _userRecord(
  String sessionId, {
  required String cwd,
  bool isSidechain = false,
  String timestamp = "2026-08-04T10:00:00.000Z",
  String? branch,
}) => {
  "type": "user",
  "sessionId": sessionId,
  "cwd": cwd,
  "isSidechain": isSidechain,
  "timestamp": timestamp,
  "version": "2.1.221",
  "gitBranch": ?branch,
};

void _writeSession(
  Directory claudeHome, {
  required String id,
  required String cwd,
  String project = "-work-alpha",
  String? title,
  String? branch,
  String timestamp = "2026-08-04T10:00:00.000Z",
}) {
  _writeTranscript(
    claudeHome,
    project: project,
    name: "$id.jsonl",
    records: [
      _userRecord(id, cwd: cwd, timestamp: timestamp, branch: branch),
      if (title != null) {"type": "ai-title", "aiTitle": title, "sessionId": id},
    ],
  );
}

String _writeTranscript(
  Directory claudeHome, {
  required String project,
  required String name,
  required List<Map<String, Object?>> records,
}) {
  final path = p.join(claudeHome.path, "projects", project, name);
  Directory(p.dirname(path)).createSync(recursive: true);
  File(path).writeAsStringSync("${records.map(jsonEncode).join("\n")}\n");
  return path;
}

void _setModified(Directory claudeHome, {required String id, required DateTime to, String project = "-work-alpha"}) {
  File(p.join(claudeHome.path, "projects", project, "$id.jsonl")).setLastModifiedSync(to);
}

class _ThrowingTranscriptApi implements ClaudeTranscriptApi {
  @override
  List<String> listTranscriptPaths() => throw const FileSystemException("cannot enumerate transcripts");

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
