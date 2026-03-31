import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_shared/sesori_shared.dart";

import "../worktree_service.dart" show ProcessRunner;

const _generatedFileSuffixes = <String>[
  ".freezed.dart",
  ".g.dart",
  ".steps.dart",
  ".config.dart",
];

class BaseCommitUnreachableException implements Exception {
  final String message;
  const BaseCommitUnreachableException({required this.message});
  @override
  String toString() => message;
}

class GitDiffQueryException implements Exception {
  final String message;
  const GitDiffQueryException({required this.message});
  @override
  String toString() => message;
}

Future<List<FileDiff>> computeSessionDiffs({
  required String worktreePath,
  required String baseCommit,
  required ProcessRunner processRunner,
}) async {
  if (!Directory(worktreePath).existsSync()) {
    return const <FileDiff>[];
  }

  final verifyCommit = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: ["rev-parse", "--verify", baseCommit],
  );
  if (verifyCommit.exitCode != 0) {
    throw BaseCommitUnreachableException(
      message: "base commit '$baseCommit' is not reachable",
    );
  }

  final nameStatusResult = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: [
      "diff",
      "--no-ext-diff",
      "--no-color",
      "--no-renames",
      "--name-status",
      baseCommit,
    ],
  );
  if (nameStatusResult.exitCode != 0) {
    throw const GitDiffQueryException(message: "git diff --name-status failed");
  }

  final numstatResult = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: [
      "diff",
      "--no-ext-diff",
      "--no-color",
      "--no-renames",
      "--numstat",
      baseCommit,
    ],
  );
  if (numstatResult.exitCode != 0) {
    throw const GitDiffQueryException(message: "git diff --numstat failed");
  }

  final statusEntries = _parseNameStatus(nameStatusResult.stdout.toString());
  final statsByFile = _parseNumstat(numstatResult.stdout.toString());

  final filteredEntries = statusEntries.where((entry) => !_isGeneratedFile(entry.file)).toList(growable: false);

  final diffs = <FileDiff>[];
  for (final entry in filteredEntries) {
    final counts = statsByFile[entry.file] ?? const (additions: 0, deletions: 0);

    final before = await _readBefore(
      processRunner: processRunner,
      worktreePath: worktreePath,
      baseCommit: baseCommit,
      file: entry.file,
      status: entry.status,
    );
    final after = _readAfter(
      worktreePath: worktreePath,
      file: entry.file,
      status: entry.status,
    );

    diffs.add(
      FileDiff(
        file: entry.file,
        before: before,
        after: after,
        additions: counts.additions,
        deletions: counts.deletions,
        status: entry.status,
      ),
    );
  }

  return diffs;
}

Future<ProcessResult> _runGit({
  required ProcessRunner processRunner,
  required String worktreePath,
  required List<String> arguments,
}) {
  return processRunner("git", arguments, workingDirectory: worktreePath);
}

List<({String file, FileDiffStatus? status})> _parseNameStatus(String output) {
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

    entries.add((file: file, status: _parseStatus(statusToken)));
  }

  return entries;
}

Map<String, ({int additions, int deletions})> _parseNumstat(String output) {
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

FileDiffStatus? _parseStatus(String token) {
  if (token.startsWith("R") || token.startsWith("C")) {
    return FileDiffStatus.modified;
  }
  return switch (token) {
    "A" => FileDiffStatus.added,
    "D" => FileDiffStatus.deleted,
    "M" => FileDiffStatus.modified,
    _ => null,
  };
}

Future<String> _readBefore({
  required ProcessRunner processRunner,
  required String worktreePath,
  required String baseCommit,
  required String file,
  required FileDiffStatus? status,
}) async {
  if (status == FileDiffStatus.added) {
    return "";
  }

  final result = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: ["show", "$baseCommit:$file"],
  );

  if (result.exitCode != 0) return "";

  final stdout = result.stdout.toString();
  if (stdout.contains("\x00")) return "";
  return stdout;
}

String _readAfter({
  required String worktreePath,
  required String file,
  required FileDiffStatus? status,
}) {
  if (status == FileDiffStatus.deleted) return "";

  final absoluteWorktreePath = p.normalize(p.absolute(worktreePath));
  final candidatePath = p.normalize(p.absolute(p.join(worktreePath, file)));
  if (candidatePath != absoluteWorktreePath && !p.isWithin(absoluteWorktreePath, candidatePath)) {
    return "";
  }

  final entityType = FileSystemEntity.typeSync(candidatePath, followLinks: false);
  if (entityType == FileSystemEntityType.link || entityType == FileSystemEntityType.notFound) {
    return "";
  }

  final fileOnDisk = File(candidatePath);
  if (!fileOnDisk.existsSync()) {
    return "";
  }

  String resolvedPath;
  try {
    resolvedPath = p.normalize(fileOnDisk.resolveSymbolicLinksSync());
  } on FileSystemException {
    return "";
  }
  final normalizedWorktreePath = p.normalize(
    Directory(worktreePath).resolveSymbolicLinksSync(),
  );
  if (resolvedPath != normalizedWorktreePath && !p.isWithin(normalizedWorktreePath, resolvedPath)) {
    return "";
  }
  try {
    return fileOnDisk.readAsStringSync();
  } on FileSystemException {
    return "";
  } on FormatException {
    return "";
  }
}

bool _isGeneratedFile(String filePath) {
  return _generatedFileSuffixes.any(filePath.endsWith);
}
