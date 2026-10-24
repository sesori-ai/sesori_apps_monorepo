import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "models/claude_subagent_meta_dto.dart";
import "models/claude_transcript_record_dto.dart";

/// Layer-1 filesystem boundary for Claude Code's on-disk transcripts.
///
/// The environment map is injected so tests can pin the root without touching
/// the developer's real `~/.claude`. `HOME` is resolved through
/// [resolveUserHomeDirectory] and is **never overridden** by this package —
/// doing so breaks the CLI's macOS keychain lookup and reports a logged-in user
/// as logged out. `CLAUDE_CONFIG_DIR` is the supported isolation knob.
///
/// Every read is synchronous so the catalog can hoist the whole call tree into
/// `Isolate.run`.
class ClaudeTranscriptApi({required Map<String, String> environment}) {
  final Map<String, String> _environment = Map.unmodifiable(environment);

  /// How many leading lines [readHeader] decodes.
  ///
  /// Everything the catalog needs — working directory, session id, git branch,
  /// CLI version, creation time, and the `ai-title` record — sits in the first
  /// few lines. Measured across 60 real transcripts the title record's line
  /// number was at most 50 (median 13), so 64 clears the observed range with
  /// margin. A title written past the bound is still found by
  /// [readTailTitleRecords] once the CLI re-appends it.
  ///
  /// The bound is what makes enumeration affordable: reading these transcripts
  /// in full meant 1,060 MiB across 1,888 files on the machine this was
  /// measured on.
  static const int headerLineBudget = 64;

  /// How many trailing bytes [readTailTitleRecords] scans.
  ///
  /// The CLI keeps re-appending a session's title records as its transcript
  /// grows, so a `/rename` made long after the header still sits near the end.
  /// Across real transcripts of up to 400 MB the newest title record was at
  /// most 31 KB from the end on CLI 2.1.310.
  static const int tailByteBudget = 64 * 1024;

  /// `$CLAUDE_CONFIG_DIR`, else `<home>/.claude`. Null when no home resolves.
  String? get claudeHome {
    final explicit = _environment["CLAUDE_CONFIG_DIR"];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final home = resolveUserHomeDirectory(environment: _environment);
    if (home == null) return null;
    return p.join(home, ".claude");
  }

  String? get projectsDirectory {
    final home = claudeHome;
    return home == null ? null : p.join(home, "projects");
  }

  /// Every `*.jsonl` under `projects/`, including subagent transcripts.
  ///
  /// Filtering those out is the catalog's job, not this layer's: the filename
  /// convention is a catalog concern and this layer reports what is on disk.
  List<String> listTranscriptPaths() {
    final root = projectsDirectory;
    if (root == null) return const [];
    final directory = Directory(root);
    if (!directory.existsSync()) return const [];

    final paths = <String>[];
    for (final entity in directory.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith(".jsonl")) continue;
      paths.add(entity.path);
    }
    return paths;
  }

  /// Decodes at most [headerLineBudget] leading records.
  List<ClaudeTranscriptLineDto> readHeader({required String transcriptPath}) {
    final file = File(transcriptPath);
    final lines = _readPrefixLines(file: file, maxLines: headerLineBudget);
    // The budget can cut the last line mid-record, exactly like a transcript
    // still being appended to, so the same suppression applies.
    return _decodeRecords(lines, ignoreMalformedLastLine: true);
  }

  /// Decodes the `custom-title` and `ai-title` records within the last
  /// [tailByteBudget] bytes.
  ///
  /// The tail is mostly tool output, so other lines are dropped before they
  /// are decoded. The CLI writes compact JSON, which makes the type a plain
  /// substring; the same text inside a prompt is escaped and never matches.
  List<ClaudeTranscriptLineDto> readTailTitleRecords({required String transcriptPath}) {
    final handle = File(transcriptPath).openSync();
    final int start;
    final List<int> bytes;
    try {
      final length = handle.lengthSync();
      // One byte before the window, so a record starting exactly at the
      // window's edge stays whole.
      start = length > tailByteBudget ? length - tailByteBudget - 1 : 0;
      handle.setPositionSync(start);
      bytes = handle.readSync(length - start);
    } finally {
      handle.closeSync();
    }
    final lines = const LineSplitter().convert(const Utf8Decoder(allowMalformed: true).convert(bytes));
    // The first line is the end of a record before the window, or empty.
    final titles = [
      for (final line in start > 0 ? lines.skip(1) : lines)
        if (_titleTypes.any(line.contains)) line,
    ];
    return _decodeRecords(titles, ignoreMalformedLastLine: true);
  }

  static const List<String> _titleTypes = ['"type":"custom-title"', '"type":"ai-title"'];

  /// Decodes every record in a transcript.
  List<ClaudeTranscriptLineDto> readTranscript({required String transcriptPath}) {
    final file = File(transcriptPath);
    final decoded = const Utf8Decoder(allowMalformed: true).convert(file.readAsBytesSync());
    return _decodeRecords(const LineSplitter().convert(decoded), ignoreMalformedLastLine: true);
  }

  /// Last-modified time, which for an append-only transcript is the session's
  /// last activity. Null when the file is gone or unreadable.
  DateTime? lastModified({required String transcriptPath}) {
    final file = File(transcriptPath);
    if (!file.existsSync()) return null;
    return file.lastModifiedSync().toUtc();
  }

  void deleteTranscript({required String transcriptPath}) {
    final file = File(transcriptPath);
    if (!file.existsSync()) return;
    file.deleteSync();
  }

  /// Removes a directory tree, e.g. a root session's `<session-id>/` folder
  /// holding its `subagents/`. A missing directory is not an error.
  void deleteDirectory({required String directoryPath}) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) return;
    directory.deleteSync(recursive: true);
  }

  /// The `<stem>.meta.json` beside a sub-agent transcript, or null when there
  /// is none. Read and decode failures throw; what a missing or broken meta
  /// *means* is the catalog's decision.
  ClaudeSubagentMetaDto? readSubagentMeta({required String transcriptPath}) {
    final file = File(subagentMetaPath(transcriptPath: transcriptPath));
    if (!file.existsSync()) return null;
    return ClaudeSubagentMetaDto.fromJson(jsonDecodeMap(file.readAsStringSync()));
  }

  static String subagentMetaPath({required String transcriptPath}) =>
      "${transcriptPath.substring(0, transcriptPath.length - ".jsonl".length)}.meta.json";

  /// Reads whole lines until [maxLines] newlines have been seen, so a bounded
  /// header read of a 17 MiB transcript touches only its first few kilobytes.
  List<String> _readPrefixLines({required File file, required int maxLines}) {
    final bytes = <int>[];
    final handle = file.openSync();
    try {
      var lineCount = 0;
      while (lineCount < maxLines) {
        final chunk = handle.readSync(8192);
        if (chunk.isEmpty) break;
        for (final byte in chunk) {
          bytes.add(byte);
          if (byte == 0x0A) {
            lineCount += 1;
            if (lineCount == maxLines) break;
          }
        }
      }
    } finally {
      handle.closeSync();
    }
    // A bounded read can split a multi-byte rune, and a transcript can hold any
    // UTF-8 the user typed, so decoding must not throw on the boundary.
    return const LineSplitter().convert(const Utf8Decoder(allowMalformed: true).convert(bytes));
  }

  List<ClaudeTranscriptLineDto> _decodeRecords(
    List<String> lines, {
    required bool ignoreMalformedLastLine,
  }) {
    final records = <ClaudeTranscriptLineDto>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      Map<String, dynamic>? json;
      try {
        json = jsonDecodeMap(line);
        records.add((record: ClaudeTranscriptRecordDto.fromJson(json), raw: Map.unmodifiable(json)));
      } on Object catch (error) {
        // The CLI appends to a live transcript, so a half-written final line is
        // expected rather than a fault, and is not warned about.
        if (ignoreMalformedLastLine && i == lines.length - 1) continue;
        Log.w(
          "[claude] skipping malformed transcript record "
          "(recordIndex=${i + 1}, ${_shapeForLog(json)}, error=${_decodeErrorForLog(error)})",
        );
      }
    }
    return records;
  }
}

/// Describes a record without quoting it.
///
/// Transcript records hold prompts, file contents, and tool output — all user
/// data with no debugging value here. Only `type` is reported, and only when it
/// is a plain identifier, because it is a closed protocol vocabulary rather
/// than user input. Everything else is reduced to a key count.
String _shapeForLog(Map<String, dynamic>? json) {
  if (json == null) return "shape=unparseable-json";
  final type = json["type"];
  final safeType = type is String && _typePattern.hasMatch(type) ? type : "<redacted>";
  return "type=$safeType, keys=${json.length}";
}

final RegExp _typePattern = RegExp(r"^[a-zA-Z0-9_-]{1,40}$");

/// Strips the offending text out of decode failures.
///
/// A [FormatException] echoes the source it failed on, which for a transcript
/// is user data, so only its offset survives.
String _decodeErrorForLog(Object error) {
  if (error is FormatException) return "FormatException(offset=${error.offset ?? "unknown"})";
  if (error is TypeError) return "TypeError";
  return error.runtimeType.toString();
}
