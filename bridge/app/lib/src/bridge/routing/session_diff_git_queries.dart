import "dart:convert";
import "dart:io";
import "package:path/path.dart" as p;
import "package:sesori_shared/sesori_shared.dart";
import "../worktree_service.dart" show ProcessRunner;

const _generatedFileSuffixes = <String>[".freezed.dart", ".g.dart", ".steps.dart", ".config.dart"];
const _maxDiffContentBytes = 100 * 1024;

/// Safely decode [Process.run] stdout, which may be a [String] or [List<int>].
/// Never throws — falls back to lossy decoding on malformed input.
String _decodeOutput(Object? out) {
  if (out is String) return out;
  if (out is List<int>) {
    try {
      return utf8.decode(out);
    } on FormatException {
      return utf8.decode(out, allowMalformed: true);
    }
  }
  return "";
}

final _hexHashPattern = RegExp(r'^[0-9a-f]{4,40}$');

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
  if (!Directory(worktreePath).existsSync()) return const <FileDiff>[];
  // Reject non-hex baseCommit to prevent git option injection (e.g. "--git-dir=...")
  if (!_hexHashPattern.hasMatch(baseCommit)) {
    throw BaseCommitUnreachableException(message: "invalid base commit format: '$baseCommit'");
  }
  final verifyCommit = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: ["rev-parse", "--verify", baseCommit],
  );
  if (verifyCommit.exitCode != 0) {
    throw BaseCommitUnreachableException(message: "base commit '$baseCommit' is not reachable");
  }
  final nameStatusResult = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: ["diff", "--no-ext-diff", "--no-color", "--no-renames", "--name-status", baseCommit],
  );
  if (nameStatusResult.exitCode != 0) {
    throw const GitDiffQueryException(message: "git diff --name-status failed");
  }
  final numstatResult = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: ["diff", "--no-ext-diff", "--no-color", "--no-renames", "--numstat", baseCommit],
  );
  if (numstatResult.exitCode != 0) {
    throw const GitDiffQueryException(message: "git diff --numstat failed");
  }

  final statusEntries = _parseNameStatus(_decodeOutput(nameStatusResult.stdout));
  final statsByFile = _parseNumstat(_decodeOutput(numstatResult.stdout));
  final filteredEntries = statusEntries.where((entry) => !_isGeneratedFile(entry.file)).toList(growable: false);

  final diffs = <FileDiff>[];
  for (final entry in filteredEntries) {
    final counts = statsByFile[entry.file] ?? const (additions: 0, deletions: 0);
    final beforeResult = await _readBefore(
      processRunner: processRunner,
      worktreePath: worktreePath,
      baseCommit: baseCommit,
      file: entry.file,
      status: entry.status,
    );
    final afterResult = _readAfter(worktreePath: worktreePath, file: entry.file, status: entry.status);
    if (beforeResult is _FileReadError || afterResult is _FileReadError) {
      diffs.add(FileDiff.skipped(file: entry.file, reason: FileDiffSkipReason.readError, status: entry.status));
      continue;
    }
    if (beforeResult is _FileBinary || afterResult is _FileBinary) {
      diffs.add(FileDiff.skipped(file: entry.file, reason: FileDiffSkipReason.binary, status: entry.status));
      continue;
    }

    final before = _contentOrEmpty(beforeResult);
    final after = _contentOrEmpty(afterResult);
    if (before.length + after.length > _maxDiffContentBytes) {
      diffs.add(FileDiff.skipped(file: entry.file, reason: FileDiffSkipReason.tooLarge, status: entry.status));
      continue;
    }
    diffs.add(
      FileDiff.content(
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
  if (token.startsWith("R") || token.startsWith("C")) return FileDiffStatus.modified;
  return switch (token) {
    "A" => FileDiffStatus.added,
    "D" => FileDiffStatus.deleted,
    "M" => FileDiffStatus.modified,
    _ => null,
  };
}

Future<_FileReadResult> _readBefore({
  required ProcessRunner processRunner,
  required String worktreePath,
  required String baseCommit,
  required String file,
  required FileDiffStatus? status,
}) async {
  if (status == FileDiffStatus.added) return const _FileContent(content: "", exists: false);
  final result = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: ["show", "$baseCommit:$file"],
  );
  if (result.exitCode != 0) return const _FileReadError();
  final stdout = _decodeOutput(result.stdout);
  if (stdout.contains("\x00")) return const _FileBinary();
  return _FileContent(content: stdout, exists: true);
}

_FileReadResult _readAfter({required String worktreePath, required String file, required FileDiffStatus? status}) {
  if (status == FileDiffStatus.deleted) return const _FileContent(content: "", exists: false);
  final absoluteWorktreePath = p.normalize(p.absolute(worktreePath));
  final candidatePath = p.normalize(p.absolute(p.join(worktreePath, file)));
  if (candidatePath != absoluteWorktreePath && !p.isWithin(absoluteWorktreePath, candidatePath)) {
    return const _FileReadError();
  }

  final entityType = FileSystemEntity.typeSync(candidatePath, followLinks: false);
  if (entityType == FileSystemEntityType.link || entityType == FileSystemEntityType.notFound) {
    return const _FileContent(content: "", exists: false);
  }

  final fileOnDisk = File(candidatePath);
  if (!fileOnDisk.existsSync()) return const _FileContent(content: "", exists: false);
  String resolvedPath;
  try {
    resolvedPath = p.normalize(fileOnDisk.resolveSymbolicLinksSync());
  } on FileSystemException {
    return const _FileReadError();
  }
  final normalizedWorktreePath = p.normalize(Directory(worktreePath).resolveSymbolicLinksSync());
  if (resolvedPath != normalizedWorktreePath && !p.isWithin(normalizedWorktreePath, resolvedPath)) {
    return const _FileReadError();
  }
  try {
    final content = fileOnDisk.readAsStringSync();
    if (content.contains("\x00")) return const _FileBinary();
    return _FileContent(content: content, exists: true);
  } on FileSystemException {
    try {
      final bytes = fileOnDisk.readAsBytesSync();
      if (bytes.contains(0)) return const _FileBinary();
    } on FileSystemException {
      return const _FileReadError();
    }
    return const _FileReadError();
  } on FormatException {
    return const _FileBinary();
  }
}

String _contentOrEmpty(_FileReadResult result) => switch (result) {
  _FileContent(:final content) => content,
  _ => "",
};

sealed class _FileReadResult {
  const _FileReadResult({required this.exists});
  final bool exists;
}

final class _FileContent extends _FileReadResult {
  final String content;
  const _FileContent({required this.content, required super.exists});
}

final class _FileBinary extends _FileReadResult {
  const _FileBinary() : super(exists: true);
}

final class _FileReadError extends _FileReadResult {
  const _FileReadError() : super(exists: false);
}

bool _isGeneratedFile(String filePath) => _generatedFileSuffixes.any(filePath.endsWith);
