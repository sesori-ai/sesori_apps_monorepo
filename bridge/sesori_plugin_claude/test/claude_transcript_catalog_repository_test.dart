import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, LogLevel;
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

    test("builds a session from a transcript header", () async {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha", title: "Refactor the parser", branch: "main");

      final record = (await catalog.listSessionRecordsInIsolate()).single;

      expect(record.id, _sessionA);
      expect(record.cwd, "/work/alpha");
      expect(record.title, "Refactor the parser");
      expect(record.gitBranch, "main");
      expect(record.cliVersion, "2.1.221");
      expect(record.createdAt, DateTime.utc(2026, 8, 4, 10));
      expect(record.updatedAt, isNotNull);
    });

    test("skips subagent transcripts, which outnumber sessions on disk", () async {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "agent-aristotle-plan-5bfd2a36f892f25b.jsonl",
        records: [_userRecord(_sessionA, cwd: "/work/alpha", isSidechain: true)],
      );

      expect((await catalog.listSessionRecordsInIsolate()).map((record) => record.id), [_sessionA]);
    });

    test("skips a UUID-named transcript that holds only subagent records", () async {
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          _userRecord(_sessionA, cwd: "/work/alpha", isSidechain: true),
          _userRecord(_sessionA, cwd: "/work/alpha", isSidechain: true),
        ],
      );

      expect(await catalog.listSessionRecordsInIsolate(), isEmpty);
    });

    test("skips a transcript whose records claim a different session", () async {
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [_userRecord(_sessionB, cwd: "/work/alpha")],
      );

      expect(await catalog.listSessionRecordsInIsolate(), isEmpty);
    });

    test("accepts records without a session id because the filename is authoritative", () async {
      final record = _userRecord(_sessionA, cwd: "/work/alpha")..remove("sessionId");
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [record],
      );

      expect((await catalog.listSessionRecordsInIsolate()).single.cwd, "/work/alpha");
    });

    test("does not borrow metadata from records for another session", () async {
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

      final record = (await catalog.listSessionRecordsInIsolate()).single;

      expect(record.cwd, "/work/alpha");
      expect(record.title, "Right title");
    });

    test("skips a transcript with no working directory to attribute it to", () async {
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          {"type": "queue-operation", "sessionId": _sessionA, "operation": "enqueue"},
        ],
      );

      expect(await catalog.listSessionRecordsInIsolate(), isEmpty);
    });

    test("leaves a session untitled when it has neither a title nor a prompt", () async {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");

      expect((await catalog.listSessionRecordsInIsolate()).single.title, isNull);
    });

    test("treats a blank title as untitled", () async {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha", title: "   ");

      expect((await catalog.listSessionRecordsInIsolate()).single.title, isNull);
    });

    test("prefers a /rename over the CLI's own title", () async {
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          _userRecord(_sessionA, cwd: "/work/alpha", uuid: "u1", content: "Fix the parser"),
          {"type": "custom-title", "customTitle": "Parser work", "sessionId": _sessionA},
          {"type": "ai-title", "aiTitle": "Fix CSV parser", "sessionId": _sessionA},
        ],
      );

      expect((await catalog.listSessionRecordsInIsolate()).single.title, "Parser work");
    });

    test("takes the newest titles from the transcript tail", () async {
      final path = _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          _userRecord(_sessionA, cwd: "/work/alpha"),
          {"type": "ai-title", "aiTitle": "First title", "sessionId": _sessionA},
          for (var i = 0; i < ClaudeTranscriptApi.tailByteBudget ~/ 1000 + 10; i++)
            {"type": "progress", "data": "x" * 1000},
          {"type": "ai-title", "aiTitle": "Newest title", "sessionId": _sessionA},
        ],
      );

      expect((await catalog.listSessionRecordsInIsolate()).single.title, "Newest title");

      File(path).writeAsStringSync(
        "${jsonEncode({"type": "custom-title", "customTitle": "Renamed late", "sessionId": _sessionA})}\n",
        mode: FileMode.append,
      );

      expect((await catalog.listSessionRecordsInIsolate()).single.title, "Renamed late");
    });

    test("titles an unnamed session with its first typed prompt", () async {
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          _userRecord(_sessionA, cwd: "/work/alpha", uuid: "u1", content: "<command-name>/clear</command-name>"),
          _userRecord(_sessionA, cwd: "/work/alpha", uuid: "u2", content: "Injected skill body", isMeta: true),
          _userRecord(
            _sessionA,
            cwd: "/work/alpha",
            uuid: "u3",
            content: [
              {"type": "text", "text": "  Rename the\n\nCSV   parser  "},
            ],
          ),
          _userRecord(_sessionA, cwd: "/work/alpha", uuid: "u4", content: "A later prompt"),
        ],
      );

      expect((await catalog.listSessionRecordsInIsolate()).single.title, "Rename the CSV parser");
    });

    test("bounds a first prompt used as a title", () async {
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [_userRecord(_sessionA, cwd: "/work/alpha", uuid: "u1", content: "a" * 300)],
      );

      expect((await catalog.listSessionRecordsInIsolate()).single.title, "${"a" * 100}…");
    });

    test("titles a dedicated-worktree session with its prompt, not the bridge note", () async {
      final note = buildWorktreeSystemContext(worktreePath: "/tmp/worktrees/blue-otter", baseBranch: "main");
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          _userRecord(
            _sessionA,
            cwd: "/work/alpha",
            uuid: "u1",
            content: [
              {"type": "text", "text": note},
              {"type": "text", "text": "visible prompt"},
            ],
          ),
        ],
      );

      expect((await catalog.listSessionRecordsInIsolate()).single.title, "visible prompt");
    });

    test("orders sessions newest first with undated ones last", () async {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha", timestamp: "2026-08-01T10:00:00.000Z");
      _writeSession(claudeHome, id: _sessionB, cwd: "/work/alpha", timestamp: "2026-08-03T10:00:00.000Z");
      _setModified(claudeHome, id: _sessionA, to: DateTime.utc(2026, 8, 1, 10));
      _setModified(claudeHome, id: _sessionB, to: DateTime.utc(2026, 8, 3, 10));

      expect((await catalog.listSessionRecordsInIsolate()).map((record) => record.id), [_sessionB, _sessionA]);
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

      final alpha = await catalog.getSessions(projectId: "/work/alpha/");

      expect(alpha.map((session) => session.id), [_sessionA]);
    });

    test("resolves a transcript path by session id without reading it", () async {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");

      expect(p.basename(await catalog.findTranscriptPath(sessionId: _sessionA) ?? "missing"), "$_sessionA.jsonl");
      expect(await catalog.findTranscriptPath(sessionId: _sessionB), isNull);
      expect((await catalog.findSessionById(sessionId: _sessionA))?.cwd, "/work/alpha");
      expect(await catalog.findSessionById(sessionId: _sessionB), isNull);
    });

    test("deletes a session's transcript and reports a missing one as not deleted", () async {
      _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");

      expect(await catalog.deleteSession(sessionId: _sessionA), isTrue);
      expect(await catalog.listSessionRecordsInIsolate(), isEmpty);
      expect(await catalog.deleteSession(sessionId: _sessionA), isFalse);
    });

    test("reports no sessions when no home resolves", () async {
      final catalog = ClaudeTranscriptCatalogRepository(
        transcriptApi: ClaudeTranscriptApi(environment: const {}),
      );

      expect(await catalog.listSessionRecordsInIsolate(), isEmpty);
    });

    test("surfaces transcript enumeration failures", () {
      final catalog = ClaudeTranscriptCatalogRepository(
        transcriptApi: _ThrowingTranscriptApi(),
      );

      expect(catalog.listSessionRecordsInIsolate(), throwsA(isA<FileSystemException>()));
    });

    group("cache", () {
      test("an unchanged second scan parses no file", () async {
        _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha", title: "First");
        _writeSession(claudeHome, id: _sessionB, cwd: "/work/alpha", title: "Other");

        final logs = await _captureDebugLogs(() async {
          await catalog.listSessionRecordsInIsolate();
          await catalog.listSessionRecordsInIsolate();
        });

        expect(_scanLines(logs), ["files=2, parsed=2", "files=2, parsed=0"]);
      });

      test("re-parses a modified transcript", () async {
        _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha", title: "Before");
        _setModified(claudeHome, id: _sessionA, to: DateTime.utc(2026, 8, 5, 12));
        expect((await catalog.listSessionRecordsInIsolate()).single.title, "Before");

        _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha", title: "After the rename");
        _setModified(claudeHome, id: _sessionA, to: DateTime.utc(2026, 8, 5, 13));

        expect((await catalog.listSessionRecordsInIsolate()).single.title, "After the rename");
      });

      test("evicts a deleted transcript", () async {
        _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");
        _writeSession(claudeHome, id: _sessionB, cwd: "/work/alpha");
        await catalog.listSessionRecordsInIsolate();

        File(p.join(claudeHome.path, "projects", "-work-alpha", "$_sessionB.jsonl")).deleteSync();

        expect((await catalog.listSessionRecordsInIsolate()).map((record) => record.id), [_sessionA]);
        expect(catalog.cachedSessionById(sessionId: _sessionB), isNull);
      });

      test("re-parses a child when only its meta file changes", () async {
        _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");
        final child = _writeTranscript(
          claudeHome,
          project: "-work-alpha",
          name: p.join(_sessionA, "subagents", "agent-a1.jsonl"),
          records: [_userRecord(_sessionA, cwd: "/work/alpha", isSidechain: true)],
        );
        final meta = File(ClaudeTranscriptApi.subagentMetaPath(transcriptPath: child))
          ..writeAsStringSync(jsonEncode({"agentType": "general-purpose", "description": "Old"}));
        expect(await _childTitle(catalog), "Old");

        meta.writeAsStringSync(jsonEncode({"agentType": "general-purpose", "description": "Renamed task"}));

        expect(await _childTitle(catalog), "Renamed task");
      });

      test("answers a lookup hit without scanning", () async {
        _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");
        await catalog.listSessionRecordsInIsolate();

        final logs = await _captureDebugLogs(() async {
          expect((await catalog.findSessionById(sessionId: _sessionA))?.cwd, "/work/alpha");
          expect(await catalog.findTranscriptPath(sessionId: _sessionA), isNotNull);
          expect(await catalog.getChildSessions(sessionId: _sessionA), isEmpty);
        });

        expect(_scanLines(logs), isEmpty);
      });

      test("rescans once on a miss", () async {
        _writeSession(claudeHome, id: _sessionA, cwd: "/work/alpha");
        await catalog.listSessionRecordsInIsolate();
        _writeSession(claudeHome, id: _sessionB, cwd: "/work/beta");

        final logs = await _captureDebugLogs(() async {
          expect((await catalog.findSessionById(sessionId: _sessionB))?.cwd, "/work/beta");
          expect(await catalog.findSessionById(sessionId: _indexedSessionId(9)), isNull);
        });

        expect(_scanLines(logs), ["files=2, parsed=1", "files=2, parsed=0"]);
      });
    });
  });
}

Future<String?> _childTitle(ClaudeTranscriptCatalogRepository catalog) async =>
    (await catalog.listSessionRecordsInIsolate()).singleWhere((record) => record.parentId != null).title;

Future<String> _captureDebugLogs(Future<void> Function() action) async {
  final previousLevel = Log.level;
  final stderr = BufferingStdout();
  try {
    Log.level = LogLevel.debug;
    await IOOverrides.runZoned(action, stderr: () => stderr);
  } finally {
    Log.level = previousLevel;
  }
  return stderr.text;
}

List<String> _scanLines(String logs) => RegExp(
  r"transcript catalog scan: (files=\d+, parsed=\d+)",
).allMatches(logs).map((match) => match.group(1) ?? "").toList();

const String _sessionA = "11111111-2222-4333-8444-555555555555";
const String _sessionB = "66666666-7777-4888-8999-aaaaaaaaaaaa";

String _indexedSessionId(int index) => "0000000$index-2222-4333-8444-555555555555";

Map<String, Object?> _userRecord(
  String sessionId, {
  required String cwd,
  bool isSidechain = false,
  String timestamp = "2026-08-04T10:00:00.000Z",
  String? branch,
  String? uuid,
  Object? content,
  bool isMeta = false,
}) => {
  "type": "user",
  "sessionId": sessionId,
  "cwd": cwd,
  "isSidechain": isSidechain,
  "timestamp": timestamp,
  "version": "2.1.221",
  "gitBranch": ?branch,
  "uuid": ?uuid,
  if (content != null) "message": {"role": "user", "content": content},
  if (isMeta) "isMeta": true,
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

class _ThrowingTranscriptApi() implements ClaudeTranscriptApi {
  @override
  List<String> listTranscriptPaths() => throw const FileSystemException("cannot enumerate transcripts");

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
