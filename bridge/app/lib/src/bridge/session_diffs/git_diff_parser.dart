import "package:sesori_shared/sesori_shared.dart";

List<({String file, FileDiffStatus? status})> parseNameStatus(String output) {
  final entries = <({String file, FileDiffStatus? status})>[];
  for (final rawLine in output.split("\n")) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final parts = line.split("\t");
    if (parts.length < 2) continue;
    final statusToken = parts.first.trim();
    if (statusToken.isEmpty) continue;
    final file = parts.last.trim();
    if (file.isEmpty) continue;
    entries.add((file: file, status: parseStatus(statusToken)));
  }
  return entries;
}

Map<String, ({int additions, int deletions})> parseNumstat(String output) {
  final byFile = <String, ({int additions, int deletions})>{};
  for (final rawLine in output.split("\n")) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final parts = line.split("\t");
    if (parts.length < 3) continue;
    final file = parts.last.trim();
    if (file.isEmpty) continue;
    final additionsToken = parts[0].trim();
    final deletionsToken = parts[1].trim();
    final additions = additionsToken == "-" ? 0 : int.tryParse(additionsToken) ?? 0;
    final deletions = deletionsToken == "-" ? 0 : int.tryParse(deletionsToken) ?? 0;
    byFile[file] = (additions: additions, deletions: deletions);
  }
  return byFile;
}

FileDiffStatus? parseStatus(String token) {
  if (token.startsWith("R") || token.startsWith("C")) return FileDiffStatus.modified;
  return switch (token) {
    "A" => FileDiffStatus.added,
    "D" => FileDiffStatus.deleted,
    "M" => FileDiffStatus.modified,
    _ => null,
  };
}

/// Parses one path per line from `git ls-files --others --exclude-standard`.
List<String> parseUntrackedPaths(String output) {
  final paths = <String>[];
  for (final rawLine in output.split("\n")) {
    final path = rawLine.endsWith("\r") ? rawLine.substring(0, rawLine.length - 1) : rawLine;
    if (path.isEmpty) continue;
    paths.add(path);
  }
  return paths;
}

/// Merges tracked diff entries with untracked paths, preserving tracked order.
List<({String file, FileDiffStatus? status})> mergeTrackedAndUntrackedEntries({
  required List<({String file, FileDiffStatus? status})> trackedEntries,
  required List<String> untrackedPaths,
}) {
  final seen = trackedEntries.map((entry) => entry.file).toSet();
  final merged = List<({String file, FileDiffStatus? status})>.from(trackedEntries);
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
