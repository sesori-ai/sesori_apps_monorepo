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
    return [
      for (final line in file.readAsLinesSync())
        if (line.trim().isNotEmpty)
          (
            entry: _decodeIndexEntry(line),
            raw: line,
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
    final lines = file.readAsLinesSync();
    final scanLimit = lines.length < 32 ? lines.length : 32;
    return _decodeRolloutLines(
      lines.take(scanLimit),
      malformedWarning: "[codex] skipping malformed rollout header record",
    );
  }

  List<CodexRolloutLineDto> readTranscript({required String rolloutPath}) {
    final file = File(rolloutPath);
    if (!file.existsSync()) return const [];
    return _decodeRolloutLines(file.readAsLinesSync());
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

  CodexSessionIndexEntryDto? _decodeIndexEntry(String line) {
    try {
      return CodexSessionIndexEntryDto.fromJson(jsonDecodeMap(line));
    } on Object {
      // Codex appends this file live, so a partial final line is expected.
      return null;
    }
  }

  List<CodexRolloutLineDto> _decodeRolloutLines(
    Iterable<String> lines, {
    String? malformedWarning,
  }) {
    final decoded = <CodexRolloutLineDto>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        decoded.add(CodexRolloutLineDto.fromJson(jsonDecodeMap(line)));
      } on Object catch (error, stackTrace) {
        if (malformedWarning != null) {
          Log.w(malformedWarning, error, stackTrace);
        }
      }
    }
    return decoded;
  }
}
