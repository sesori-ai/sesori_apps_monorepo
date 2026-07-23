import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "models/codex_rollout_dto.dart";

typedef CodexSessionIndexLine = ({CodexSessionIndexEntryDto? entry, String raw});

class CodexRolloutTailChunk {
  const CodexRolloutTailChunk({
    required this.lines,
    required this.nextOffset,
    required this.trailingBytes,
  });

  final List<CodexRolloutLineDto> lines;
  final int nextOffset;
  final List<int> trailingBytes;
}

class CodexRolloutTailPosition {
  const CodexRolloutTailPosition({
    required this.offset,
    required this.trailingBytes,
  });

  final int offset;
  final List<int> trailingBytes;
}

/// Layer-1 filesystem boundary for Codex's on-disk rollout history.
class CodexRolloutApi {
  CodexRolloutApi({Map<String, String>? environment}) : _environment = environment ?? Platform.environment;

  final Map<String, String> _environment;

  String? get codexHome {
    final explicit = _environment["CODEX_HOME"];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final home = resolveUserHomeDirectory(environment: _environment);
    if (home == null) return null;
    return p.join(home, ".codex");
  }

  String? get indexPath {
    final home = codexHome;
    return home == null ? null : p.join(home, "session_index.jsonl");
  }

  String? get sessionsDirectory {
    final home = codexHome;
    return home == null ? null : p.join(home, "sessions");
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
              lines[i],
              warnOnMalformed: i < lines.length - 1,
            ),
            raw: lines[i],
          ),
    ];
  }

  List<String> listRolloutPaths() {
    final root = sessionsDirectory;
    if (root == null) return const [];
    final directory = Directory(root);
    if (!directory.existsSync()) return const [];
    return [
      for (final entity in directory.listSync(recursive: true, followLinks: false))
        if (entity is File &&
            p.basename(entity.path).startsWith("rollout-") &&
            p.basename(entity.path).endsWith(".jsonl"))
          entity.path,
    ];
  }

  List<CodexRolloutLineDto> readHeader({required String rolloutPath}) {
    final file = File(rolloutPath);
    if (!file.existsSync()) return const [];
    return _decodeRolloutLines(
      _readPrefixLines(file: file, maxLines: 32),
      malformedWarning: "[codex] skipping malformed rollout header record",
    );
  }

  List<CodexRolloutLineDto> readTranscript({required String rolloutPath}) {
    final file = File(rolloutPath);
    if (!file.existsSync()) return const [];
    return _decodeRolloutLines(
      file.readAsLinesSync(),
      malformedWarning: "[codex] skipping malformed rollout transcript record",
      ignoreMalformedLastLine: true,
    );
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
        // COMPATIBILITY 2026-07-23 (Codex JSONL writer): tailing starts at
        // logical EOF but must retain an already-written partial final record.
        // Otherwise its later newline would be decoded without the skipped
        // prefix. Remove with the live JSONL tail workaround itself.
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
          rawLines,
          malformedWarning: "[codex] skipping malformed live rollout transcript record",
        ),
        nextOffset: length,
        // COMPATIBILITY 2026-07-23 (Codex JSONL writer): an observer can read
        // between the record bytes and their terminating newline. Retain that
        // suffix without warning; remove only if Codex exposes atomic appended
        // records instead of a concurrently-written JSONL file.
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

  CodexSessionIndexEntryDto? _decodeIndexEntry(
    String line, {
    required bool warnOnMalformed,
  }) {
    try {
      return CodexSessionIndexEntryDto.fromJson(jsonDecodeMap(line));
    } on Object {
      if (warnOnMalformed) {
        Log.w("[codex] skipping malformed session index record");
      }
      return null;
    }
  }

  List<CodexRolloutLineDto> _decodeRolloutLines(
    Iterable<String> lines, {
    String? malformedWarning,
    bool ignoreMalformedLastLine = false,
  }) {
    final source = lines.toList(growable: false);
    final decoded = <CodexRolloutLineDto>[];
    for (var i = 0; i < source.length; i++) {
      final line = source[i];
      if (line.trim().isEmpty) continue;
      Object? json;
      var parsedJson = false;
      try {
        json = jsonDecode(line);
        parsedJson = true;
        decoded.add(
          CodexRolloutLineDto.fromJson(
            (json! as Map).cast<String, dynamic>(),
          ),
        );
      } on Object catch (error) {
        final isExpectedPartialLine = ignoreMalformedLastLine && i == source.length - 1;
        if (malformedWarning != null && !isExpectedPartialLine) {
          final schema = parsedJson ? _jsonSchemaForLog(json) : "unparseable-json";
          Log.w(
            "$malformedWarning "
            "(recordIndex=${i + 1}, schema=$schema, "
            "error=${_decodeErrorForLog(error)})",
          );
        }
      }
    }
    return decoded;
  }

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
    return const LineSplitter().convert(utf8.decode(bytes));
  }
}

/// Describes rollout JSON without logging transcript values.
///
/// Rollouts can contain prompts, source code, command output, paths, and
/// credentials. Field names and bounded type structure are enough to diagnose
/// schema drift, so only schema discriminator values are retained.
String _jsonSchemaForLog(
  Object? value, {
  String? fieldName,
  int depth = 0,
}) {
  const maxDepth = 5;
  const maxEntries = 16;
  const maxListItems = 8;

  if (value == null) return "null";
  if (value is String) {
    // Only the record and payload discriminators are structural. A nested
    // `type` can belong to tool input and must remain redacted.
    if (depth <= 2 &&
        (fieldName == "type" || fieldName == "role") &&
        RegExp(r"^[A-Za-z][A-Za-z0-9_.-]{0,63}$").hasMatch(value)) {
      return '"$value"';
    }
    return "String";
  }
  if (value is bool) return "bool";
  if (value is num) return value.runtimeType.toString();
  if (value is List) {
    if (depth >= maxDepth) return "List";
    if (value.isEmpty) return "List<empty>";
    final itemSchemas = <String>{};
    for (final item in value.take(maxListItems)) {
      itemSchemas.add(_jsonSchemaForLog(item, depth: depth + 1));
    }
    final suffix = value.length > maxListItems ? ",…" : "";
    return "List<${itemSchemas.join("|")}$suffix>";
  }
  if (value is Map) {
    if (depth >= maxDepth) return "Map";
    final entries = value.entries.take(maxEntries).map((entry) {
      final key = entry.key;
      final safeKey = key is String && RegExp(r"^[A-Za-z_][A-Za-z0-9_.-]{0,63}$").hasMatch(key)
          ? key
          : "<${key.runtimeType}-key>";
      return "$safeKey:${_jsonSchemaForLog(entry.value, fieldName: safeKey, depth: depth + 1)}";
    });
    final suffix = value.length > maxEntries ? ",…" : "";
    return "{${entries.join(",")}$suffix}";
  }
  return value.runtimeType.toString();
}

/// Keeps decoder diagnostics useful without letting an exception echo raw JSON.
String _decodeErrorForLog(Object error) {
  if (error is FormatException) {
    return "FormatException(offset=${error.offset ?? "unknown"})";
  }
  if (error is TypeError) return error.toString();
  return error.runtimeType.toString();
}
