import "dart:io";

import "package:sesori_shared/sesori_shared.dart";

import "../foundation/process_runner.dart";
import "exceptions.dart";
import "file_content_reader.dart";
import "git_diff_parser.dart";

Future<List<FileDiff>> computeSessionDiffs({
  required String worktreePath,
  required String baseBranch,
  required ProcessRunner processRunner,
}) async {
  if (!Directory(worktreePath).existsSync()) return const <FileDiff>[];
  if (baseBranch.isEmpty) {
    throw const BaseBranchUnreachableException(message: "invalid base branch format: ''");
  }

  final verifyBranch = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: ["rev-parse", "--verify", baseBranch],
  );
  if (verifyBranch.exitCode != 0) {
    throw BaseBranchUnreachableException(message: "base branch '$baseBranch' is not reachable");
  }

  final mergeBaseResult = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: ["merge-base", baseBranch, "HEAD"],
  );
  if (mergeBaseResult.exitCode != 0) {
    final stderr = decodeOutput(mergeBaseResult.stderr).trim();
    if (mergeBaseResult.exitCode == 1) {
      throw BaseBranchUnreachableException(message: "no common ancestor between '$baseBranch' and HEAD");
    }
    throw GitDiffQueryException(
      message: "git merge-base failed (exit ${mergeBaseResult.exitCode}): $stderr",
    );
  }
  final mergeBaseSha = _parseSingleSha(decodeOutput(mergeBaseResult.stdout));
  if (mergeBaseSha == null) {
    throw const GitDiffQueryException(message: "git merge-base returned unexpected output");
  }

  final nameStatusResult = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: ["diff", "--no-ext-diff", "--no-color", "--no-renames", "--name-status", mergeBaseSha],
  );
  if (nameStatusResult.exitCode != 0) {
    throw const GitDiffQueryException(message: "git diff --name-status failed");
  }

  final numstatResult = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: ["diff", "--no-ext-diff", "--no-color", "--no-renames", "--numstat", mergeBaseSha],
  );
  if (numstatResult.exitCode != 0) {
    throw const GitDiffQueryException(message: "git diff --numstat failed");
  }

  final untrackedResult = await _runGit(
    processRunner: processRunner,
    worktreePath: worktreePath,
    arguments: ["ls-files", "--others", "--exclude-standard"],
  );
  if (untrackedResult.exitCode != 0) {
    throw const GitDiffQueryException(message: "git ls-files --others failed");
  }

  final statusEntries = mergeTrackedAndUntrackedEntries(
    trackedEntries: parseNameStatus(decodeOutput(nameStatusResult.stdout)),
    untrackedPaths: parseUntrackedPaths(decodeOutput(untrackedResult.stdout)),
  );
  final statsByFile = parseNumstat(decodeOutput(numstatResult.stdout));
  final diffs = <FileDiff>[];

  for (final entry in statusEntries) {
    final counts = statsByFile[entry.file] ?? const (additions: 0, deletions: 0);
    final beforeResult = await readBefore(
      processRunner: processRunner,
      worktreePath: worktreePath,
      baseBranch: mergeBaseSha,
      file: entry.file,
      status: entry.status,
    );
    final afterResult = readAfter(
      worktreePath: worktreePath,
      file: entry.file,
      status: entry.status,
    );

    if (beforeResult is FileReadError || afterResult is FileReadError) {
      diffs.add(
        FileDiff.skipped(
          file: entry.file,
          reason: FileDiffSkipReason.readError,
          status: entry.status,
        ),
      );
      continue;
    }

    if (beforeResult is FileTooLarge || afterResult is FileTooLarge) {
      diffs.add(
        FileDiff.skipped(
          file: entry.file,
          reason: FileDiffSkipReason.tooLarge,
          status: entry.status,
        ),
      );
      continue;
    }

    if (beforeResult is FileBinary || afterResult is FileBinary) {
      diffs.add(
        FileDiff.skipped(
          file: entry.file,
          reason: FileDiffSkipReason.binary,
          status: entry.status,
        ),
      );
      continue;
    }

    final before = contentOrEmpty(beforeResult);
    final after = contentOrEmpty(afterResult);
    final isUntracked = !statsByFile.containsKey(entry.file);
    final lineCounts = isUntracked && after.isNotEmpty
        ? (additions: _countLines(after), deletions: 0)
        : switch (entry.status) {
            FileDiffStatus.modified
                when counts.additions == 0 &&
                    after.isNotEmpty &&
                    before != after &&
                    (counts.deletions == 0 || !_isDeletionOnlyChange(before, after)) =>
              (additions: _countLines(after), deletions: counts.deletions > 0 ? counts.deletions : _countLines(before)),
            _ => counts,
          };
    if (before.length + after.length > maxFileContentBytes) {
      diffs.add(
        FileDiff.skipped(
          file: entry.file,
          reason: FileDiffSkipReason.tooLarge,
          status: entry.status,
        ),
      );
      continue;
    }

    diffs.add(
      FileDiff.content(
        file: entry.file,
        before: before,
        after: after,
        additions: lineCounts.additions,
        deletions: lineCounts.deletions,
        status: entry.status,
      ),
    );
  }

  return diffs;
}

int _countLines(String content) {
  if (content.isEmpty) return 0;
  return "\n".allMatches(content).length + (content.endsWith("\n") ? 0 : 1);
}

bool _isDeletionOnlyChange(String before, String after) {
  if (after.isEmpty) return true;
  final beforeLines = _normalizedLines(before);
  final afterLines = _normalizedLines(after);
  var beforeIndex = 0;
  for (final line in afterLines) {
    while (beforeIndex < beforeLines.length && beforeLines[beforeIndex] != line) {
      beforeIndex++;
    }
    if (beforeIndex >= beforeLines.length) return false;
    beforeIndex++;
  }
  return true;
}

List<String> _normalizedLines(String content) {
  return content.replaceAll("\r\n", "\n").split("\n").map((line) => line.replaceAll("\r", "")).toList();
}

/// Parses stdout that should contain exactly one non-empty SHA line.
/// Returns `null` if stdout is empty or contains multiple non-empty lines.
String? _parseSingleSha(String stdout) {
  final lines = stdout.split("\n").where((l) => l.trim().isNotEmpty).toList();
  if (lines.length != 1) return null;
  return lines.first.trim();
}

Future<ProcessResult> _runGit({
  required ProcessRunner processRunner,
  required String worktreePath,
  required List<String> arguments,
}) {
  return processRunner.run("git", arguments, workingDirectory: worktreePath);
}
