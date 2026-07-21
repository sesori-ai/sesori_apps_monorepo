import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "models/codex_rollout_dto.dart";

typedef CodexSessionIndexLine = ({CodexSessionIndexEntryDto? entry, String raw});

/// Layer-1 filesystem boundary for Codex's on-disk rollout history.
class CodexRolloutApi {
  CodexRolloutApi({Map<String, String>? environment}) : _environment = environment ?? Platform.environment;

  final Map<String, String> _environment;

  String? get codexHome {
    final explicit = _environment["CODEX_HOME"];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final home = _environment["HOME"] ?? _environment["USERPROFILE"];
    if (home == null || home.isEmpty) return null;
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
      try {
        decoded.add(CodexRolloutLineDto.fromJson(jsonDecodeMap(line)));
      } on Object {
        final isExpectedPartialLine = ignoreMalformedLastLine && i == source.length - 1;
        if (malformedWarning != null && !isExpectedPartialLine) {
          Log.w(malformedWarning);
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
