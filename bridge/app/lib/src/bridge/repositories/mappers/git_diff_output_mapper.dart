import "dart:convert";

import "package:sesori_shared/sesori_shared.dart" show FileDiffStatus;

typedef SessionDiffEntry = ({String file, FileDiffStatus? status});
typedef SessionDiffLineCounts = ({int additions, int deletions});

class GitDiffOutputMapper {
  const GitDiffOutputMapper();

  String decodeOutput({required Object? output}) {
    if (output is String) return output;
    if (output is List<int>) {
      try {
        return utf8.decode(output);
      } on FormatException {
        return utf8.decode(output, allowMalformed: true);
      }
    }
    return "";
  }

  String? parseSingleSha({required Object? output}) {
    final lines = decodeOutput(output: output)
        .split("\n")
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    return lines.length == 1 ? lines.single.trim() : null;
  }

  List<SessionDiffEntry> parseNameStatus({required Object? output}) {
    final entries = <SessionDiffEntry>[];
    for (final rawLine in decodeOutput(output: output).split("\n")) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final parts = line.split("\t");
      if (parts.length < 2) continue;
      final statusToken = parts.first.trim();
      final file = parts.last.trim();
      if (statusToken.isEmpty || file.isEmpty) continue;
      entries.add((file: file, status: _parseStatus(token: statusToken)));
    }
    return entries;
  }

  Map<String, SessionDiffLineCounts> parseNumstat({required Object? output}) {
    final byFile = <String, SessionDiffLineCounts>{};
    for (final rawLine in decodeOutput(output: output).split("\n")) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final parts = line.split("\t");
      if (parts.length < 3) continue;
      final file = parts.last.trim();
      if (file.isEmpty) continue;
      final additionsToken = parts[0].trim();
      final deletionsToken = parts[1].trim();
      byFile[file] = (
        additions: additionsToken == "-" ? 0 : int.tryParse(additionsToken) ?? 0,
        deletions: deletionsToken == "-" ? 0 : int.tryParse(deletionsToken) ?? 0,
      );
    }
    return byFile;
  }

  List<String> parseUntrackedPaths({required Object? output}) {
    final paths = <String>[];
    for (final rawLine in decodeOutput(output: output).split("\n")) {
      final path = rawLine.endsWith("\r") ? rawLine.substring(0, rawLine.length - 1) : rawLine;
      if (path.isNotEmpty) paths.add(path);
    }
    return paths;
  }

  List<SessionDiffEntry> mergeTrackedAndUntrackedEntries({
    required List<SessionDiffEntry> trackedEntries,
    required List<String> untrackedPaths,
  }) {
    final seen = trackedEntries.map((entry) => entry.file).toSet();
    final merged = List<SessionDiffEntry>.from(trackedEntries);
    for (final path in untrackedPaths) {
      if (seen.contains(path)) {
        final existingIndex = merged.indexWhere((entry) => entry.file == path);
        if (existingIndex != -1 && merged[existingIndex].status == FileDiffStatus.deleted) {
          merged[existingIndex] = (file: path, status: FileDiffStatus.modified);
        }
        continue;
      }
      merged.add((file: path, status: FileDiffStatus.added));
      seen.add(path);
    }
    return merged;
  }

  FileDiffStatus? _parseStatus({required String token}) {
    if (token.startsWith("R") || token.startsWith("C")) return FileDiffStatus.modified;
    return switch (token) {
      "A" => FileDiffStatus.added,
      "D" => FileDiffStatus.deleted,
      "M" => FileDiffStatus.modified,
      _ => null,
    };
  }
}
