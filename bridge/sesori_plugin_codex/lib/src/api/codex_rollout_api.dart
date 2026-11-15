import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "models/codex_desktop_state_dto.dart";
import "models/codex_rollout_dto.dart";
import "models/codex_rollout_file_name.dart";

typedef CodexSessionIndexLine = ({CodexSessionIndexEntryDto? entry, String raw});

class const CodexRolloutTailChunk({
  required final List<CodexRolloutLineDto> lines,
  required final int nextOffset,
  required final List<int> trailingBytes,
});

class const CodexRolloutTailPosition({
  required final int offset,
  required final List<int> trailingBytes,
});

/// The bounded leading window of a rollout, with the file length observed
/// before reading it.
class const CodexRolloutHeader({
  required final List<CodexRolloutLineDto> lines,
  required final bool reachedLineLimit,
  required final int fileLength,
});

class const CodexDesktopStateReadException({required final Object cause}) implements Exception {
  @override
  String toString() => "Codex Desktop state read failed (${cause.runtimeType})";
}

/// Codex's state directory, resolved as codex itself does: `$CODEX_HOME` when
/// set, otherwise `.codex` under the user home.
String? resolveCodexHome({required Map<String, String> environment}) {
  final explicit = environment["CODEX_HOME"];
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final home = resolveUserHomeDirectory(environment: environment);
  if (home == null) return null;
  return p.join(home, ".codex");
}

/// The creation time a UUIDv7 id encodes in its leading 48 bits, or null for
/// any other id. Codex thread and rollout ids are UUIDv7.
DateTime? codexUuidV7Time({required String id}) {
  final match = _uuidV7Pattern.firstMatch(id);
  if (match == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(int.parse("${match[1]}${match[2]}", radix: 16));
}

final RegExp _uuidV7Pattern = RegExp(
  r"^([0-9a-f]{8})-([0-9a-f]{4})-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
  caseSensitive: false,
);

/// Layer-1 filesystem boundary for Codex's on-disk local state and rollout history.
class CodexRolloutApi({required final Map<String, String> _environment}) {
  String? get codexHome => resolveCodexHome(environment: _environment);

  String? get indexPath {
    final home = codexHome;
    return home == null ? null : p.join(home, "session_index.jsonl");
  }

  String? get sessionsDirectory {
    final home = codexHome;
    return home == null ? null : p.join(home, "sessions");
  }

  String? get archivedSessionsDirectory {
    final home = codexHome;
    return home == null ? null : p.join(home, "archived_sessions");
  }

  String? get desktopStatePath {
    final home = codexHome;
    return home == null ? null : p.join(home, ".codex-global-state.json");
  }

  String? get documentsCodexDirectory {
    final home = resolveUserHomeDirectory(environment: _environment);
    return home == null ? null : p.join(home, "Documents", "Codex");
  }

  Future<CodexDesktopStateDto> readDesktopState() async {
    final path = desktopStatePath;
    if (path == null) {
      return const CodexDesktopStateDto(projectlessThreadIds: {});
    }
    try {
      return CodexDesktopStateDto.fromJson(
        jsonDecodeMap(await File(path).readAsString()),
      );
    } on PathNotFoundException {
      return const CodexDesktopStateDto(projectlessThreadIds: {});
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CodexDesktopStateReadException(cause: error),
        stackTrace,
      );
    }
  }

  List<CodexSessionIndexEntryDto> readSessionIndex() => [
    for (final line in readSessionIndexLines()) ?line.entry,
  ];

  List<CodexSessionIndexLine> readSessionIndexLines() {
    final path = indexPath;
    if (path == null) return const [];
    final file = File(path);
    if (!file.existsSync()) return const [];
    final lines = file.readAsLinesSync();
    return [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].trim().isNotEmpty)
          (
            entry: _decodeIndexEntry(
              line: lines[i],
              warnOnMalformed: i < lines.length - 1,
            ),
            raw: lines[i],
          ),
    ];
  }

  List<String> listRolloutPaths() {
    final root = sessionsDirectory;
    if (root == null) return const [];
    return _listRolloutFiles(directory: root, recursive: true, test: (_) => true);
  }

  /// [sessionId]'s newest rollout filed from [oldest] to [newest], or null,
  /// without listing every rollout. Codex files each rollout under
  /// `sessions/YYYY/MM/DD` for its own creation date, so a revert's rollout
  /// sits on a later day than the thread's first one. Days are searched
  /// newest first, one day past each end to cover midnight and a UTC date.
  String? findNewestRolloutPathBetween({
    required String sessionId,
    required DateTime oldest,
    required DateTime newest,
  }) {
    final root = sessionsDirectory;
    if (root == null) return null;
    final first = DateTime(oldest.year, oldest.month, oldest.day - 1);
    for (
      var day = DateTime(newest.year, newest.month, newest.day + 1);
      !day.isBefore(first);
      day = DateTime(day.year, day.month, day.day - 1)
    ) {
      String? newestPath;
      CodexRolloutFileName? newestName;
      for (final path in _listRolloutFiles(
        directory: _dayDirectory(root: root, day: day),
        recursive: false,
        test: (name) => name.threadId == sessionId,
      )) {
        final name = CodexRolloutFileName.tryParse(fileName: p.basename(path));
        if (name == null || (newestName != null && !name.isNewerThan(other: newestName))) continue;
        newestName = name;
        newestPath = path;
      }
      if (newestPath != null) return newestPath;
    }
    return null;
  }

  /// The rollout file named by [rolloutId], active or archived, or null.
  /// Rollout ids are UUIDv7, so the file's creation-date directories are
  /// searched first; a full listing covers an archived or older rollout.
  String? findRolloutPathByRolloutId({required String rolloutId}) {
    bool matches(CodexRolloutFileName name) => name.rolloutId == rolloutId;
    final sessions = sessionsDirectory;
    final createdAt = codexUuidV7Time(id: rolloutId);
    if (sessions != null && createdAt != null) {
      for (final day in [
        createdAt,
        createdAt.subtract(const Duration(days: 1)),
        createdAt.add(const Duration(days: 1)),
      ]) {
        final directory = _dayDirectory(root: sessions, day: day);
        if (_listRolloutFiles(directory: directory, recursive: false, test: matches).firstOrNull case final path?) {
          return path;
        }
      }
    }
    for (final root in [archivedSessionsDirectory, sessions].nonNulls) {
      if (_listRolloutFiles(directory: root, recursive: true, test: matches).firstOrNull case final path?) return path;
    }
    return null;
  }

  String _dayDirectory({required String root, required DateTime day}) => p.join(
    root,
    day.year.toString(),
    day.month.toString().padLeft(2, "0"),
    day.day.toString().padLeft(2, "0"),
  );

  List<String> _listRolloutFiles({
    required String directory,
    required bool recursive,
    required bool Function(CodexRolloutFileName name) test,
  }) {
    final root = Directory(directory);
    if (!root.existsSync()) return const [];
    return [
      for (final entity in root.listSync(recursive: recursive, followLinks: false))
        if (entity is File)
          if (CodexRolloutFileName.tryParse(fileName: p.basename(entity.path)) case final name? when test(name))
            entity.path,
    ];
  }

  CodexRolloutHeader readHeader({required String rolloutPath}) {
    final file = File(rolloutPath);
    if (!file.existsSync()) return const CodexRolloutHeader(lines: [], reachedLineLimit: false, fileLength: 0);
    // Measured before reading so a concurrent append only ever invalidates.
    final fileLength = file.lengthSync();
    final (:lines, :isComplete) = _readPrefixLines(file: file, maxLines: 32);
    return CodexRolloutHeader(
      lines: _decodeRolloutLines(
        lines: lines,
        malformedWarning: "[codex] skipping malformed rollout header record",
      ),
      reachedLineLimit: isComplete,
      fileLength: fileLength,
    );
  }

  /// Null when the rollout can no longer be stat'ed (removed or inaccessible).
  int? rolloutLength({required String rolloutPath}) {
    try {
      return File(rolloutPath).lengthSync();
    } on FileSystemException {
      return null;
    }
  }

  /// Fresh native activity evidence without decoding the rollout transcript.
  DateTime? lastModified({required String rolloutPath}) {
    try {
      return File(rolloutPath).lastModifiedSync().toUtc();
    } on PathNotFoundException {
      return null;
    }
  }

  List<CodexRolloutLineDto> readTranscript({required String rolloutPath}) {
    final file = File(rolloutPath);
    if (!file.existsSync()) return const [];
    return _decodeRolloutLines(
      lines: file.readAsLinesSync(),
      malformedWarning: "[codex] skipping malformed rollout transcript record",
      ignoreMalformedLastLine: true,
    );
  }

  /// The records in the first [endByteOffset] bytes of a rollout: the kept
  /// prefix a later rollout's `history_base` names. Codex never rewrites
  /// those bytes, so the prefix ends on a record boundary.
  List<CodexRolloutLineDto> readTranscriptPrefix({required String rolloutPath, required int endByteOffset}) {
    final handle = File(rolloutPath).openSync();
    try {
      final bytes = handle.readSync(endByteOffset);
      return _decodeRolloutLines(
        lines: const LineSplitter().convert(utf8.decode(bytes)),
        malformedWarning: "[codex] skipping malformed rollout history base record",
      );
    } finally {
      handle.closeSync();
    }
  }

  CodexRolloutTailPosition rolloutTailPosition({
    required String rolloutPath,
  }) {
    final file = File(rolloutPath);
    if (!file.existsSync()) {
      return const CodexRolloutTailPosition(
        offset: 0,
        trailingBytes: [],
      );
    }
    final handle = file.openSync();
    try {
      final length = handle.lengthSync();
      var position = length;
      final reverseSuffixChunks = <List<int>>[];
      while (position > 0) {
        final start = position > 8192 ? position - 8192 : 0;
        handle.setPositionSync(start);
        final bytes = handle.readSync(position - start);
        final newline = bytes.lastIndexOf(0x0A);
        if (newline >= 0) {
          reverseSuffixChunks.add(bytes.sublist(newline + 1));
          break;
        }
        reverseSuffixChunks.add(bytes);
        position = start;
      }
      return CodexRolloutTailPosition(
        offset: length,
        // COMPATIBILITY 2026-11-03 (v1.12.0): The Codex JSONL writer can leave
        // a partial final record. Tailing starts at logical EOF but must retain
        // it, or its later newline would be decoded without the skipped prefix.
        // Remove with the live JSONL tail workaround itself.
        trailingBytes: [
          for (final chunk in reverseSuffixChunks.reversed) ...chunk,
        ],
      );
    } finally {
      handle.closeSync();
    }
  }

  CodexRolloutTailChunk readTranscriptChunk({
    required String rolloutPath,
    required int offset,
    required List<int> trailingBytes,
  }) {
    final file = File(rolloutPath);
    if (!file.existsSync()) {
      return CodexRolloutTailChunk(
        lines: const [],
        nextOffset: offset,
        trailingBytes: trailingBytes,
      );
    }
    final handle = file.openSync();
    try {
      final length = handle.lengthSync();
      if (offset > length) {
        throw StateError(
          "Codex rollout shrank while being tailed: $rolloutPath "
          "(offset=$offset, length=$length)",
        );
      }
      handle.setPositionSync(offset);
      final appended = handle.readSync(length - offset);
      if (appended.isEmpty) {
        return CodexRolloutTailChunk(
          lines: const [],
          nextOffset: offset,
          trailingBytes: trailingBytes,
        );
      }
      final combined = <int>[...trailingBytes, ...appended];
      final lastNewline = combined.lastIndexOf(0x0A);
      if (lastNewline < 0) {
        return CodexRolloutTailChunk(
          lines: const [],
          nextOffset: length,
          trailingBytes: combined,
        );
      }
      final completeBytes = combined.sublist(0, lastNewline);
      final remainingBytes = combined.sublist(lastNewline + 1);
      final rawLines = <String>[];
      var lineStart = 0;
      for (var i = 0; i <= completeBytes.length; i++) {
        if (i != completeBytes.length && completeBytes[i] != 0x0A) continue;
        final bytes = completeBytes.sublist(lineStart, i);
        lineStart = i + 1;
        if (bytes.isEmpty) continue;
        rawLines.add(utf8.decode(bytes));
      }
      return CodexRolloutTailChunk(
        lines: _decodeRolloutLines(
          lines: rawLines,
          malformedWarning: "[codex] skipping malformed live rollout transcript record",
        ),
        nextOffset: length,
        // COMPATIBILITY 2026-11-03 (v1.12.0): With the Codex JSONL writer, an
        // observer can read between the record bytes and their terminating
        // newline. Retain that suffix without warning; remove only if Codex
        // exposes atomic appended records instead of a concurrently-written
        // JSONL file.
        trailingBytes: remainingBytes,
      );
    } finally {
      handle.closeSync();
    }
  }

  void deleteRollout({required String rolloutPath}) {
    final file = File(rolloutPath);
    if (file.existsSync()) file.deleteSync();
  }

  void writeSessionIndex({required List<String> lines}) {
    final path = indexPath;
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;
    file.writeAsStringSync(lines.isEmpty ? "" : "${lines.join("\n")}\n");
  }

  CodexSessionIndexEntryDto? _decodeIndexEntry({required String line, required bool warnOnMalformed}) {
    try {
      return CodexSessionIndexEntryDto.fromJson(jsonDecodeMap(line));
    } on Object {
      if (warnOnMalformed) {
        Log.w("[codex] skipping malformed session index record");
      }
      return null;
    }
  }

  List<CodexRolloutLineDto> _decodeRolloutLines({
    required Iterable<String> lines,
    required String malformedWarning,
    bool ignoreMalformedLastLine = false,
  }) {
    final source = lines.toList(growable: false);
    final decoded = <CodexRolloutLineDto>[];
    for (var i = 0; i < source.length; i++) {
      final line = source[i];
      if (line.trim().isEmpty) continue;
      Map<String, dynamic>? json;
      try {
        json = jsonDecodeMap(line);
        decoded.add(CodexRolloutLineDto.fromJson(json));
      } on Object catch (error) {
        final isExpectedPartialLine = ignoreMalformedLastLine && i == source.length - 1;
        if (!isExpectedPartialLine) {
          final schema = json != null ? _rolloutSchemaForLog(value: json) : "unparseable-json";
          Log.w(
            "$malformedWarning "
            "(recordIndex=${i + 1}, schema=$schema, "
            "error=${_decodeErrorForLog(error: error)})",
          );
        }
      }
    }
    return decoded;
  }

  ({List<String> lines, bool isComplete}) _readPrefixLines({required File file, required int maxLines}) {
    final bytes = BytesBuilder(copy: false);
    final handle = file.openSync();
    var lineCount = 0;
    try {
      while (lineCount < maxLines) {
        final chunk = handle.readSync(64 * 1024);
        if (chunk.isEmpty) break;
        var end = chunk.length;
        for (var i = 0; i < chunk.length; i++) {
          if (chunk[i] != 0x0A) continue;
          lineCount += 1;
          if (lineCount == maxLines) {
            end = i + 1;
            break;
          }
        }
        bytes.add(Uint8List.sublistView(chunk, 0, end));
      }
    } finally {
      handle.closeSync();
    }
    return (
      lines: const LineSplitter().convert(utf8.decode(bytes.takeBytes())),
      isComplete: lineCount == maxLines,
    );
  }
}

const _rolloutSchemaKeyNames = {
  "timestamp",
  "type",
  "payload",
  "id",
  "cwd",
  "model_provider",
  "cli_version",
  "model",
  "role",
  "content",
  "summary",
  "call_id",
  "name",
  "arguments",
  "internal_chat_message_metadata_passthrough",
  "turn_id",
  "input",
  "output",
  "action",
  "query",
  "cell_id",
  "text",
  "status",
  "result",
  "revised_prompt",
  "saved_path",
};

/// Describes malformed Codex records without logging source or tool input.
String _rolloutSchemaForLog({required Object? value}) {
  final schema = _renderRolloutSchemaForLog(
    value: value,
    path: const <String>[],
    depth: 0,
    budget: _RolloutSchemaBudget(remainingNodes: 128),
  );
  const maxSchemaLength = 2048;
  if (schema.length <= maxSchemaLength) return schema;
  return "${schema.substring(0, maxSchemaLength - 1)}…";
}

String _renderRolloutSchemaForLog({
  required Object? value,
  required List<String>? path,
  required int depth,
  required _RolloutSchemaBudget budget,
}) {
  const maxDepth = 5;
  const maxEntries = 16;
  const maxListItems = 8;

  if (!budget.takeNode()) return "…";
  if (value == null) return "null";
  if (value is String) {
    if (path != null && _isRolloutEnumValuePath(path: path) && _schemaIdentifierPattern.hasMatch(value)) {
      return 'enum("$value")';
    }
    return "String";
  }
  if (value is bool) return "bool";
  if (value is num) return value.runtimeType.toString();
  if (value is List) {
    if (depth >= maxDepth) return "List";
    if (value.isEmpty) return "List<empty>";
    final itemSchemas = <String>{};
    var visitedItems = 0;
    for (final item in value.take(maxListItems)) {
      if (budget.isExhausted) break;
      itemSchemas.add(
        _renderRolloutSchemaForLog(
          value: item,
          path: path,
          depth: depth + 1,
          budget: budget,
        ),
      );
      visitedItems += 1;
    }
    final suffix = value.length > visitedItems ? (itemSchemas.isEmpty ? "…" : ",…") : "";
    return "List<${itemSchemas.join("|")}$suffix>";
  }
  if (value is Map) {
    if (depth >= maxDepth) return "Map";
    final entries = <String>[];
    var visitedEntries = 0;
    for (final entry in value.entries.take(maxEntries)) {
      if (budget.isExhausted) break;
      final key = entry.key;
      final keyIsSafe = key is String && _rolloutSchemaKeyNames.contains(key) && _schemaKeyPattern.hasMatch(key);
      final safeKey = keyIsSafe ? key : "<redacted-key>";
      entries.add(
        "$safeKey:${_renderRolloutSchemaForLog(
          value: entry.value,
          path: keyIsSafe && path != null ? [...path, key] : null,
          depth: depth + 1,
          budget: budget,
        )}",
      );
      visitedEntries += 1;
    }
    final suffix = value.length > visitedEntries ? (entries.isEmpty ? "…" : ",…") : "";
    return "{${entries.join(",")}$suffix}";
  }
  return value.runtimeType.toString();
}

bool _isRolloutEnumValuePath({required List<String> path}) {
  if (path.length == 1) return path.single == "type";
  return path.length == 2 &&
      path.first == "payload" &&
      (path.last == "type" || path.last == "role" || path.last == "status");
}

class _RolloutSchemaBudget({required var int remainingNodes}) {
  bool get isExhausted => remainingNodes == 0;

  bool takeNode() {
    if (isExhausted) return false;
    remainingNodes -= 1;
    return true;
  }
}

final RegExp _schemaIdentifierPattern = RegExp(
  r"^[A-Za-z][A-Za-z0-9_.-]{0,63}$",
);
final RegExp _schemaKeyPattern = RegExp(
  r"^[A-Za-z_][A-Za-z0-9_.-]{0,63}$",
);

/// Keeps decoder diagnostics useful without letting an exception echo raw JSON.
String _decodeErrorForLog({required Object error}) {
  if (error is FormatException) {
    return "FormatException(offset=${error.offset ?? "unknown"})";
  }
  if (error is TypeError) return error.toString();
  return error.runtimeType.toString();
}
