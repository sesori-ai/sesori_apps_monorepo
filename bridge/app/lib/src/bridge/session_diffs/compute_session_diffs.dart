import "dart:io";

import "package:sesori_shared/sesori_shared.dart";

import "../worktree_service.dart" show ProcessRunner;
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
    if (mergeBaseResult.exitCode == 1) {
      throw BaseBranchUnreachableException(message: "no common ancestor between '$baseBranch' and HEAD");
    }
    throw const GitDiffQueryException(message: "git merge-base failed");
  }
  final mergeBaseSha = decodeOutput(mergeBaseResult.stdout).trim();
  if (mergeBaseSha.isEmpty) {
    throw const GitDiffQueryException(message: "git merge-base returned empty result");
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

  final statusEntries = parseNameStatus(decodeOutput(nameStatusResult.stdout));
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
