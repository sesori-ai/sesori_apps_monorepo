import "../api/git_cli_api.dart";
import "mappers/git_diff_output_mapper.dart";

sealed class SessionDiffQueryResult {}

class SessionDiffQuerySuccess extends SessionDiffQueryResult {
  final String mergeBase;
  final List<SessionDiffEntry> entries;
  final Map<String, SessionDiffLineCounts> lineCountsByFile;

  SessionDiffQuerySuccess({
    required this.mergeBase,
    required this.entries,
    required this.lineCountsByFile,
  });
}

class SessionDiffBaseBranchUnreachable extends SessionDiffQueryResult {}

class SessionDiffNoCommonAncestor extends SessionDiffQueryResult {}

class SessionDiffQueryFailure extends SessionDiffQueryResult {
  final String message;

  SessionDiffQueryFailure({required this.message});
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

  Future<SessionDiffQueryResult> query({
    required String worktreePath,
    required String baseBranch,
  }) async {
    final verifyResult = await _gitCliApi.verifyRevision(
      projectPath: worktreePath,
      revision: baseBranch,
    );
    if (verifyResult.exitCode != 0) {
      return SessionDiffBaseBranchUnreachable();
    }

    final mergeBaseResult = await _gitCliApi.findMergeBase(
      projectPath: worktreePath,
      baseRevision: baseBranch,
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

    final nameStatusResult = await _gitCliApi.diffNameStatus(
      projectPath: worktreePath,
      revision: mergeBase,
    );
    if (nameStatusResult.exitCode != 0) {
      return SessionDiffQueryFailure(message: "git diff --name-status failed");
    }

    final numstatResult = await _gitCliApi.diffNumstat(
      projectPath: worktreePath,
      revision: mergeBase,
    );
    if (numstatResult.exitCode != 0) {
      return SessionDiffQueryFailure(message: "git diff --numstat failed");
    }

    final untrackedResult = await _gitCliApi.listUntrackedFiles(projectPath: worktreePath);
    if (untrackedResult.exitCode != 0) {
      return SessionDiffQueryFailure(message: "git ls-files --others failed");
    }

    return SessionDiffQuerySuccess(
      mergeBase: mergeBase,
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
