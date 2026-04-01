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
