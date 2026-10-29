// Writes a synthetic Claude Code transcript tree for heavy-user profiling.
//
// Generate (from `bridge/app/`; the output must be outside the repository):
//
//   dart run tool/benchmarks/claude_session_fixture.dart --out /tmp/claude-10k
//   dart run tool/benchmarks/claude_session_fixture.dart --out /tmp/claude-50k --sessions 50000
//
// The output is a `CLAUDE_CONFIG_DIR`: transcripts land under
// `<out>/projects/<encoded-cwd>/<uuid>.jsonl`. The tree is deterministic for a
// given `--seed`, and generation refuses a non-empty `--out`.
//
// Headless scanner and import numbers need no login:
//
//   dart run tool/benchmarks/claude_catalog_benchmark.dart --fixture /tmp/claude-10k
//
// Running the apps against the fixture needs a logged-in local bridge, because
// setup refuses imports while Claude is logged out:
//
// 1. Log in once with a dev account. This writes credentials for `<out>` only
//    and leaves the default `~/.claude` untouched:
//      CLAUDE_CONFIG_DIR=/tmp/claude-10k claude auth login
// 2. Start a local bridge on its own `--data-dir` slot, per the
//    `sesori-local-testing` skill, with `CLAUDE_CONFIG_DIR=/tmp/claude-10k` in
//    its environment, and run a Claude rescan from the app.
//
// Every session's `cwd` is a path under `--workspace` that need not exist.

import "dart:convert";
import "dart:io";
import "dart:math";

import "package:args/args.dart";
import "package:path/path.dart" as p;

const _defaultSessionCount = 10000;
const _defaultProjectCount = 40;
const _defaultSeed = 2026;
const _defaultWorkspace = "/Users/fixture/workspace";

/// Share of roots in the largest project; the rest spread evenly.
const _largestProjectShare = 0.4;

/// Share of roots with 1–3 sub-agent children.
const _childShare = 0.2;

/// Share of roots padded with filler so the scanner's 64 KiB tail read and the
/// header read's line budget see realistic files.
const _fillerShare = 0.05;
const _fillerMinBytes = 200 * 1024;
const _fillerMaxBytes = 400 * 1024;

const _cliVersion = "2.1.310";
const _year = Duration(days: 365);

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption("out", help: "Output CLAUDE_CONFIG_DIR; must be empty or absent.")
    ..addOption("sessions", defaultsTo: "$_defaultSessionCount", help: "Root transcripts to write.")
    ..addOption("projects", defaultsTo: "$_defaultProjectCount")
    ..addOption("seed", defaultsTo: "$_defaultSeed")
    ..addOption("workspace", defaultsTo: _defaultWorkspace, help: "Parent of every project's cwd.");
  final parsed = parser.parse(arguments);
  final out = parsed.option("out");
  final sessionCount = int.tryParse(parsed.option("sessions") ?? "");
  final projectCount = int.tryParse(parsed.option("projects") ?? "");
  final seed = int.tryParse(parsed.option("seed") ?? "");
  final workspace = parsed.option("workspace");
  if (out == null || sessionCount == null || sessionCount < 1 || projectCount == null || projectCount < 1) {
    stderr.writeln("usage: claude_session_fixture.dart --out <dir> [options]\n${parser.usage}");
    exitCode = 64;
    return;
  }
  final outDirectory = Directory(out);
  if (outDirectory.existsSync() && outDirectory.listSync().isNotEmpty) {
    stderr.writeln("refusing to write into non-empty $out");
    exitCode = 1;
    return;
  }

  final stopwatch = Stopwatch()..start();
  final summary = _ClaudeSessionFixture(
    root: out,
    workspace: workspace ?? _defaultWorkspace,
    sessionCount: sessionCount,
    projectCount: projectCount,
    random: Random(seed ?? _defaultSeed),
    now: DateTime.now().toUtc(),
  ).write();
  stopwatch.stop();
  stdout.writeln(
    const JsonEncoder.withIndent("  ").convert({...summary, "generationMilliseconds": stopwatch.elapsedMilliseconds}),
  );
}

class _ClaudeSessionFixture({
  required final String root,
  required final String workspace,
  required final int sessionCount,
  required final int projectCount,
  required final Random random,
  required final DateTime now,
}) {
  var _children = 0;
  var _fillerFiles = 0;
  var _bytes = 0;
  final Map<_TitleSource, int> _titles = {for (final source in _TitleSource.values) source: 0};

  Map<String, Object?> write() {
    final largest = projectCount == 1 ? sessionCount : (sessionCount * _largestProjectShare).round();
    final projectSessionCounts = <String, int>{};
    for (var index = 0; index < sessionCount; index++) {
      // The first `largest` roots go to project 0; the rest round-robin.
      final project = index < largest || projectCount == 1 ? 0 : 1 + (index - largest) % (projectCount - 1);
      final cwd = p.posix.join(workspace, "project-${project.toString().padLeft(2, "0")}");
      projectSessionCounts.update(cwd, (count) => count + 1, ifAbsent: () => 1);
      _writeRoot(index: index, cwd: cwd);
    }
    return {
      "out": root,
      "rootSessions": sessionCount,
      "childSessions": _children,
      "projects": projectSessionCounts.length,
      "largestProjectRoots": projectSessionCounts.values.reduce(max),
      "fillerFiles": _fillerFiles,
      "titles": {for (final entry in _titles.entries) entry.key.name: entry.value},
      "bytes": _bytes,
    };
  }

  void _writeRoot({required int index, required String cwd}) {
    final id = _uuid();
    final projectDirectory = p.join(root, "projects", cwd.replaceAll(RegExp("[^A-Za-z0-9]"), "-"));
    final createdAt = now.subtract(_year * random.nextDouble());
    final updatedAt = _between(createdAt, now);
    final titleSource = _TitleSource.values[random.nextInt(_TitleSource.values.length)];
    _titles.update(titleSource, (count) => count + 1);

    final lines = <Map<String, Object?>>[
      _userLine(sessionId: id, cwd: cwd, at: createdAt, text: "Session $index: ${_prompts[index % _prompts.length]}"),
      _assistantLine(sessionId: id, cwd: cwd, at: createdAt.add(const Duration(seconds: 5)), text: "On it."),
      if (titleSource == _TitleSource.generated)
        {"type": "ai-title", "aiTitle": "Generated title $index", "sessionId": id},
    ];
    if (random.nextDouble() < _fillerShare) {
      _fillerFiles++;
      final target = _fillerMinBytes + random.nextInt(_fillerMaxBytes - _fillerMinBytes);
      var written = 0;
      var turn = 0;
      while (written < target) {
        final line = _assistantLine(
          sessionId: id,
          cwd: cwd,
          at: createdAt.add(Duration(minutes: ++turn)),
          text: "Tool output $turn ${"x" * 2000}",
        );
        lines.add(line);
        written += 2200;
      }
    }
    // The CLI appends a rename at the end, which only the tail read finds.
    if (titleSource == _TitleSource.custom) {
      lines.add({"type": "custom-title", "customTitle": "Custom title $index", "sessionId": id});
    }
    _writeJsonl(path: p.join(projectDirectory, "$id.jsonl"), lines: lines, modified: updatedAt);

    if (random.nextDouble() >= _childShare) return;
    final childCount = 1 + random.nextInt(3);
    for (var child = 0; child < childCount; child++) {
      _children++;
      final agentId = _hex(16);
      final base = p.join(projectDirectory, id, "subagents", "agent-$agentId");
      final childAt = _between(createdAt, updatedAt);
      File("$base.meta.json")
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({"agentType": "general-purpose", "description": "Sub-agent $child of session $index"}),
        )
        ..setLastModifiedSync(childAt);
      _writeJsonl(
        path: "$base.jsonl",
        lines: [
          {
            ..._userLine(sessionId: id, cwd: cwd, at: childAt, text: "Investigate part $child"),
            "isSidechain": true,
            "agentId": agentId,
          },
        ],
        modified: _between(childAt, updatedAt),
      );
    }
  }

  Map<String, Object?> _userLine({
    required String sessionId,
    required String cwd,
    required DateTime at,
    required String text,
  }) => {
    "type": "user",
    "uuid": _uuid(),
    "sessionId": sessionId,
    "cwd": cwd,
    "gitBranch": "main",
    "version": _cliVersion,
    "timestamp": at.toIso8601String(),
    "isSidechain": false,
    "message": {"role": "user", "content": text},
  };

  Map<String, Object?> _assistantLine({
    required String sessionId,
    required String cwd,
    required DateTime at,
    required String text,
  }) => {
    "type": "assistant",
    "uuid": _uuid(),
    "sessionId": sessionId,
    "cwd": cwd,
    "gitBranch": "main",
    "version": _cliVersion,
    "timestamp": at.toIso8601String(),
    "isSidechain": false,
    "message": {
      "id": "msg_${_hex(24)}",
      "role": "assistant",
      "model": "claude-opus-5-5",
      "content": [
        {"type": "text", "text": text},
      ],
    },
  };

  void _writeJsonl({required String path, required List<Map<String, Object?>> lines, required DateTime modified}) {
    final content = "${lines.map(jsonEncode).join("\n")}\n";
    final file = File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    file.setLastModifiedSync(modified);
    _bytes += content.length;
  }

  DateTime _between(DateTime from, DateTime to) =>
      from.add(Duration(microseconds: (to.difference(from).inMicroseconds * random.nextDouble()).round()));

  String _hex(int length) => List.generate(length, (_) => random.nextInt(16).toRadixString(16)).join();

  String _uuid() => "${_hex(8)}-${_hex(4)}-4${_hex(3)}-a${_hex(3)}-${_hex(12)}";
}

/// Where a session's title comes from, in the scanner's precedence order.
enum _TitleSource() {
  /// A `custom-title` record (a `/rename`) at the end of the file.
  custom,

  /// An `ai-title` record in the header.
  generated,

  /// No title record; the scanner derives one from the first prompt.
  prompt,
}

const List<String> _prompts = [
  "fix the flaky login test",
  "add pagination to the orders endpoint",
  "refactor the settings screen into smaller widgets",
  "investigate the memory leak in the sync worker",
  "update dependencies and fix the analyzer warnings",
  "write release notes for the next version",
];
