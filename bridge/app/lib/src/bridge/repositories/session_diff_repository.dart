import "../api/git_cli_api.dart";
import "mappers/git_diff_output_mapper.dart";

sealed class SessionDiffQueryResult {}

class SessionDiffQuerySuccess extends SessionDiffQueryResult {
  final String baseRevision;
  final List<SessionDiffEntry> entries;
  final Map<String, SessionDiffLineCounts> lineCountsByFile;

  SessionDiffQuerySuccess({
    required this.baseRevision,
    required this.entries,
    required this.lineCountsByFile,
  });
}

class SessionDiffBaseUnreachable extends SessionDiffQueryResult {}

class SessionDiffNoCommonAncestor extends SessionDiffQueryResult {}

class SessionDiffQueryFailure extends SessionDiffQueryResult {
  final String message;

  SessionDiffQueryFailure({required this.message});
}

class SessionDiffRepositoryException implements Exception {
  final String message;

  const SessionDiffRepositoryException({required this.message});

  @override
  String toString() => message;
}

sealed class SessionDiffComparisonBase {
  final String revision;

  const SessionDiffComparisonBase({required this.revision});
}

class SessionDiffExactRevision extends SessionDiffComparisonBase {
  const SessionDiffExactRevision({required super.revision});
}

class SessionDiffMergeBaseRevision extends SessionDiffComparisonBase {
  const SessionDiffMergeBaseRevision({required super.revision});
}

sealed class SessionDiffRevisionFileReadResult {}

class SessionDiffRevisionFileContent extends SessionDiffRevisionFileReadResult {
  final String content;

  SessionDiffRevisionFileContent({required this.content});
}

class SessionDiffRevisionFileBinary extends SessionDiffRevisionFileReadResult {}

class SessionDiffRevisionFileTooLarge extends SessionDiffRevisionFileReadResult {}

class SessionDiffRevisionFileReadFailure extends SessionDiffRevisionFileReadResult {}

class SessionDiffRepository {
  final GitCliApi _gitCliApi;
  final GitDiffOutputMapper _outputMapper;

  SessionDiffRepository({
    required GitCliApi gitCliApi,
    required GitDiffOutputMapper outputMapper,
  }) : _gitCliApi = gitCliApi,
       _outputMapper = outputMapper;

  Future<String?> getCurrentBranch({
    required String projectPath,
  }) async {
    final result = await _gitCliApi.readCurrentBranch(projectPath: projectPath);
    if (result.exitCode == 1) {
      return null;
    }
    if (result.exitCode != 0) {
      throw SessionDiffRepositoryException(
        message: "git symbolic-ref failed (exit ${result.exitCode})",
      );
    }
    final branch = result.stdout.toString().trim();
    if (branch.isEmpty) {
      throw const SessionDiffRepositoryException(
        message: "git symbolic-ref returned an empty branch",
      );
    }
    return branch;
  }

  Future<bool> revisionExists({
    required String projectPath,
    required String revision,
  }) async {
    final result = await _gitCliApi.verifyRevision(
      projectPath: projectPath,
      revision: revision,
    );
    return result.exitCode == 0;
  }

  Future<bool> isAncestor({
    required String projectPath,
    required String revision,
  }) async {
    final result = await _gitCliApi.isAncestor(
      projectPath: projectPath,
      revision: revision,
    );
    if (result.exitCode == 0) {
      return true;
    }
    if (result.exitCode == 1) {
      return false;
    }
    throw SessionDiffRepositoryException(
      message: "git merge-base --is-ancestor failed (exit ${result.exitCode})",
    );
  }

  Future<SessionDiffQueryResult> query({
    required String worktreePath,
    required SessionDiffComparisonBase comparisonBase,
  }) async {
    final revision = comparisonBase.revision;
    final verifyResult = await _gitCliApi.verifyRevision(
      projectPath: worktreePath,
      revision: revision,
    );
    if (verifyResult.exitCode != 0) {
      return SessionDiffBaseUnreachable();
    }

    late final String baseRevision;
    switch (comparisonBase) {
      case SessionDiffExactRevision():
        baseRevision = revision;
      case SessionDiffMergeBaseRevision():
        final mergeBaseResult = await _gitCliApi.findMergeBase(
          projectPath: worktreePath,
          baseRevision: revision,
        );
        if (mergeBaseResult.exitCode == 1) {
          return SessionDiffNoCommonAncestor();
        }
        if (mergeBaseResult.exitCode != 0) {
          final stderr = _outputMapper.decodeOutput(output: mergeBaseResult.stderr).trim();
          return SessionDiffQueryFailure(
            message: "git merge-base failed (exit ${mergeBaseResult.exitCode}): $stderr",
          );
        }
        final mergeBase = _outputMapper.parseSingleSha(output: mergeBaseResult.stdout);
        if (mergeBase == null) {
          return SessionDiffQueryFailure(message: "git merge-base returned unexpected output");
        }
        baseRevision = mergeBase;
    }

    final nameStatusResult = await _gitCliApi.diffNameStatus(
      projectPath: worktreePath,
      revision: baseRevision,
    );
    if (nameStatusResult.exitCode != 0) {
      return SessionDiffQueryFailure(message: "git diff --name-status failed");
    }

    final numstatResult = await _gitCliApi.diffNumstat(
      projectPath: worktreePath,
      revision: baseRevision,
    );
    if (numstatResult.exitCode != 0) {
      return SessionDiffQueryFailure(message: "git diff --numstat failed");
    }

    final untrackedResult = await _gitCliApi.listUntrackedFiles(projectPath: worktreePath);
    if (untrackedResult.exitCode != 0) {
      return SessionDiffQueryFailure(message: "git ls-files --others failed");
    }

    return SessionDiffQuerySuccess(
      baseRevision: baseRevision,
      entries: _outputMapper.mergeTrackedAndUntrackedEntries(
        trackedEntries: _outputMapper.parseNameStatus(output: nameStatusResult.stdout),
        untrackedPaths: _outputMapper.parseUntrackedPaths(output: untrackedResult.stdout),
      ),
      lineCountsByFile: _outputMapper.parseNumstat(output: numstatResult.stdout),
    );
  }

  Future<SessionDiffRevisionFileReadResult> readFileAtRevision({
    required String worktreePath,
    required String revision,
    required String file,
    required int maxBytes,
  }) async {
    final sizeResult = await _gitCliApi.fileSizeAtRevision(
      projectPath: worktreePath,
      revision: revision,
      file: file,
    );
    if (sizeResult.exitCode != 0) {
      return SessionDiffRevisionFileReadFailure();
    }
    final byteCount = _outputMapper.parseByteCount(output: sizeResult.stdout);
    if (byteCount == null || byteCount < 0) {
      return SessionDiffRevisionFileReadFailure();
    }
    if (byteCount > maxBytes) {
      return SessionDiffRevisionFileTooLarge();
    }

    final result = await _gitCliApi.readFileAtRevision(
      projectPath: worktreePath,
      revision: revision,
      file: file,
    );
    if (result.exitCode != 0) {
      return SessionDiffRevisionFileReadFailure();
    }
    final content = _outputMapper.decodeOutput(output: result.stdout);
    return content.contains("\x00")
        ? SessionDiffRevisionFileBinary()
        : SessionDiffRevisionFileContent(content: content);
  }
}
