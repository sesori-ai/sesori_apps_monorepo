import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, LogLevel;
import "package:test/test.dart";

void main() {
  group("ClaudeTranscriptApi", () {
    late Directory claudeHome;
    late ClaudeTranscriptApi api;

    setUp(() {
      claudeHome = Directory.systemTemp.createTempSync("claude-home-");
      api = ClaudeTranscriptApi(environment: {"CLAUDE_CONFIG_DIR": claudeHome.path});
    });

    tearDown(() {
      try {
        claudeHome.deleteSync(recursive: true);
      } on Object {
        // Best-effort cleanup.
      }
    });

    test("prefers CLAUDE_CONFIG_DIR over the user home", () {
      final api = ClaudeTranscriptApi(
        environment: {"CLAUDE_CONFIG_DIR": "/pinned/config", "HOME": "/user/home"},
      );

      expect(api.claudeHome, "/pinned/config");
      expect(api.projectsDirectory, p.join("/pinned/config", "projects"));
    });

    test("falls back to the user home when no config dir is set", () {
      final api = ClaudeTranscriptApi(environment: {"HOME": "/user/home", "USERPROFILE": "/user/home"});

      expect(api.claudeHome, p.join("/user/home", ".claude"));
    });

    test("resolves nothing when no home is discoverable", () {
      final api = ClaudeTranscriptApi(environment: const {});

      expect(api.claudeHome, isNull);
      expect(api.projectsDirectory, isNull);
      expect(api.listTranscriptPaths(), isEmpty);
    });

    test("enumerates transcripts across project directories", () {
      _writeTranscript(claudeHome, project: "-work-alpha", name: "$_sessionA.jsonl", records: [_userRecord(_sessionA)]);
      _writeTranscript(claudeHome, project: "-work-beta", name: "$_sessionB.jsonl", records: [_userRecord(_sessionB)]);
      // Not a transcript.
      File(p.join(claudeHome.path, "projects", "-work-alpha", "notes.txt")).writeAsStringSync("x");

      final paths = api.listTranscriptPaths();

      expect(paths, hasLength(2));
      expect(paths.map(p.basename), containsAll(["$_sessionA.jsonl", "$_sessionB.jsonl"]));
    });

    test("reports subagent transcripts too, leaving the filter to the catalog", () {
      _writeTranscript(claudeHome, project: "-work-alpha", name: "$_sessionA.jsonl", records: [_userRecord(_sessionA)]);
      _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "agent-review-abc123.jsonl",
        records: [_userRecord(_sessionA)],
      );

      expect(api.listTranscriptPaths(), hasLength(2));
    });

    test("decodes the record types the catalog consumes", () {
      final path = _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          _userRecord(_sessionA, cwd: "/work/alpha", gitBranch: "main", version: "2.1.221"),
          {"type": "ai-title", "aiTitle": "Refactor the parser", "sessionId": _sessionA},
          {"type": "pr-link", "sessionId": _sessionA, "prNumber": 12},
        ],
      );

      final records = api.readTranscript(transcriptPath: path);

      expect(records, hasLength(3));
      final content = records[0] as ClaudeTranscriptContentRecord;
      expect(content.kind, ClaudeTranscriptContentKind.user);
      expect(content.cwd, "/work/alpha");
      expect(content.gitBranch, "main");
      expect(content.version, "2.1.221");
      expect(content.isSidechain, isFalse);
      expect(content.timestamp, DateTime.utc(2026, 8, 4, 10));
      expect((records[1] as ClaudeTranscriptTitleRecord).title, "Refactor the parser");
      expect((records[2] as ClaudeTranscriptUnknownRecord).type, "pr-link");
    });

    test("absorbs a record type this build does not model", () {
      final path = _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          {"type": "some-future-record", "sessionId": _sessionA, "payload": 1},
          {"sessionId": _sessionA},
        ],
      );

      final records = api.readTranscript(transcriptPath: path);

      expect(records, hasLength(2));
      expect((records[0] as ClaudeTranscriptUnknownRecord).type, "some-future-record");
      expect((records[1] as ClaudeTranscriptUnknownRecord).type, isNull);
    });

    test("treats a blank title record as unrecognized rather than an empty title", () {
      final path = _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [
          {"type": "ai-title", "aiTitle": "   ", "sessionId": _sessionA},
        ],
      );

      expect(api.readTranscript(transcriptPath: path).single, isA<ClaudeTranscriptUnknownRecord>());
    });

    test("stops the header read at the line budget", () {
      final records = [
        for (var i = 0; i < ClaudeTranscriptApi.headerLineBudget + 20; i++) _userRecord(_sessionA),
      ];
      final path = _writeTranscript(claudeHome, project: "-work-alpha", name: "$_sessionA.jsonl", records: records);

      expect(api.readHeader(transcriptPath: path), hasLength(ClaudeTranscriptApi.headerLineBudget));
      expect(api.readTranscript(transcriptPath: path), hasLength(records.length));
    });

    test("keeps every complete record when the file ends mid-write", () {
      final path = p.join(claudeHome.path, "projects", "-work-alpha", "$_sessionA.jsonl");
      Directory(p.dirname(path)).createSync(recursive: true);
      final complete = jsonEncode(_userRecord(_sessionA));
      final partial = jsonEncode(_userRecord(_sessionA));
      File(path).writeAsStringSync("$complete\n${partial.substring(0, partial.length ~/ 2)}");

      final output = _captureWarnings(() {
        expect(api.readTranscript(transcriptPath: path), hasLength(1));
      });

      expect(output, isEmpty, reason: "a half-written trailing line is expected, not a fault");
    });

    test("warns once per malformed interior record without quoting it", () {
      final path = p.join(claudeHome.path, "projects", "-work-alpha", "$_sessionA.jsonl");
      Directory(p.dirname(path)).createSync(recursive: true);
      File(path).writeAsStringSync(
        [
          jsonEncode({"type": "user", "sessionId": _sessionA, "message": "secret-prompt-text"}).replaceFirst("{", "{{"),
          jsonEncode(_userRecord(_sessionA)),
        ].join("\n"),
      );

      final output = _captureWarnings(() {
        expect(api.readTranscript(transcriptPath: path), hasLength(1));
      });

      expect("skipping malformed transcript record".allMatches(output), hasLength(1));
      expect(output, contains("recordIndex=1"));
      expect(output, isNot(contains("secret-prompt-text")));
    });

    test("reports a record shape without leaking values", () {
      final path = p.join(claudeHome.path, "projects", "-work-alpha", "$_sessionA.jsonl");
      Directory(p.dirname(path)).createSync(recursive: true);
      // A JSON array decodes cleanly but is not a record map.
      File(path).writeAsStringSync('["secret-prompt-text"]\n${jsonEncode(_userRecord(_sessionA))}');

      final output = _captureWarnings(() {
        expect(api.readTranscript(transcriptPath: path), hasLength(1));
      });

      expect(output, contains("shape=unparseable-json"));
      expect(output, isNot(contains("secret-prompt-text")));
    });

    test("reads a missing transcript as empty rather than throwing", () {
      expect(api.readTranscript(transcriptPath: p.join(claudeHome.path, "nope.jsonl")), isEmpty);
      expect(api.readHeader(transcriptPath: p.join(claudeHome.path, "nope.jsonl")), isEmpty);
      expect(api.lastModified(transcriptPath: p.join(claudeHome.path, "nope.jsonl")), isNull);
    });

    test("deletes a transcript and tolerates a repeat delete", () {
      final path = _writeTranscript(
        claudeHome,
        project: "-work-alpha",
        name: "$_sessionA.jsonl",
        records: [_userRecord(_sessionA)],
      );

      api.deleteTranscript(transcriptPath: path);
      expect(File(path).existsSync(), isFalse);
      expect(() => api.deleteTranscript(transcriptPath: path), returnsNormally);
    });
  });
}

const String _sessionA = "11111111-2222-4333-8444-555555555555";
const String _sessionB = "66666666-7777-4888-8999-aaaaaaaaaaaa";

Map<String, Object?> _userRecord(
  String sessionId, {
  String cwd = "/work/alpha",
  String? gitBranch,
  String? version,
  bool isSidechain = false,
  String timestamp = "2026-08-04T10:00:00.000Z",
}) => {
  "type": "user",
  "sessionId": sessionId,
  "cwd": cwd,
  "isSidechain": isSidechain,
  "timestamp": timestamp,
  "gitBranch": ?gitBranch,
  "version": ?version,
};

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

String _captureWarnings(void Function() action) {
  final previousLevel = Log.level;
  final stderr = _BufferingStdout();
  try {
    Log.level = LogLevel.warning;
    IOOverrides.runZoned(action, stderr: () => stderr);
  } finally {
    Log.level = previousLevel;
  }
  return stderr.text;
}

class _BufferingStdout implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
