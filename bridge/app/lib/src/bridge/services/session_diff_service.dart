import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "../repositories/mappers/git_diff_output_mapper.dart";
import "../repositories/session_diff_repository.dart";
import "../repositories/session_repository.dart";

class SessionDiffSessionNotFoundException implements Exception {}

class BaseBranchUnreachableException implements Exception {
  final String message;

  const BaseBranchUnreachableException({required this.message});

  @override
  String toString() => message;
}

class GitDiffQueryException implements Exception {
  final String message;

  const GitDiffQueryException({required this.message});

  @override
  String toString() => message;
}

sealed class _DiffFileReadResult {}

class _DiffFileContent extends _DiffFileReadResult {
  final String content;

  _DiffFileContent({required this.content});
}

class _DiffFileBinary extends _DiffFileReadResult {}

class _DiffFileTooLarge extends _DiffFileReadResult {}

class _DiffFileReadFailure extends _DiffFileReadResult {}

class SessionDiffService {
  static const _maxFileContentBytes = 200 * 1024;

  final SessionRepository _sessionRepository;
  final SessionDiffRepository _sessionDiffRepository;
  final FilesystemRepository _filesystemRepository;

  SessionDiffService({
    required SessionRepository sessionRepository,
    required SessionDiffRepository sessionDiffRepository,
    required FilesystemRepository filesystemRepository,
  }) : _sessionRepository = sessionRepository,
       _sessionDiffRepository = sessionDiffRepository,
       _filesystemRepository = filesystemRepository;

  Future<List<FileDiff>> getDiffs({required String sessionId}) async {
    final session = await _sessionRepository.getStoredSession(sessionId: sessionId);
    if (session == null) {
      throw SessionDiffSessionNotFoundException();
    }
    if (session.archivedAt != null) return const [];

    final String worktreePath;
    final String revision;
    final SessionDiffComparisonMode comparisonMode;
    if (session.isDedicated) {
      final dedicatedWorktreePath = session.worktreePath;
      final baseBranch = session.baseBranch;
      if (dedicatedWorktreePath == null || baseBranch == null) return const [];
      if (baseBranch.isEmpty) {
        throw const BaseBranchUnreachableException(message: "invalid base branch format: ''");
      }
      if (!_filesystemRepository.directoryExists(path: dedicatedWorktreePath)) return const [];
      worktreePath = dedicatedWorktreePath;
      revision = baseBranch;
      comparisonMode = SessionDiffComparisonMode.mergeBase;
    } else {
      // Imported sessions and sessions created from an already-dirty tree have
      // no exact start snapshot. They still expose the current working-tree
      // changes by falling back to HEAD.
      final startCommit = session.baseBranch == null ? session.baseCommit?.trim() : null;
      final projectPath = await _sessionRepository.getProjectPath(projectId: session.projectId);
      if (projectPath == null) return const [];
      if (!_filesystemRepository.directoryExists(path: projectPath)) return const [];
      worktreePath = projectPath;
      revision = startCommit == null || startCommit.isEmpty ? "HEAD" : startCommit;
      comparisonMode = SessionDiffComparisonMode.exactRevision;
    }
    final queryResult = await _sessionDiffRepository.query(
      worktreePath: worktreePath,
      revision: revision,
      comparisonMode: comparisonMode,
    );
    final snapshot = switch (queryResult) {
      SessionDiffQuerySuccess() => queryResult,
      SessionDiffBaseUnreachable() => throw BaseBranchUnreachableException(
        message: "diff base '$revision' is not reachable",
      ),
      SessionDiffNoCommonAncestor() => throw BaseBranchUnreachableException(
        message: "no common ancestor between '$revision' and HEAD",
      ),
      SessionDiffQueryFailure(:final message) => throw GitDiffQueryException(message: message),
    };

    final diffs = <FileDiff>[];
    for (final entry in snapshot.entries) {
      if (_filesystemRepository.isKnownBinaryFile(relativePath: entry.file)) {
        diffs.add(
          FileDiff.skipped(
            file: entry.file,
            reason: FileDiffSkipReason.binary,
            status: entry.status,
          ),
        );
        continue;
      }

      final beforeResult = await _readBefore(
        worktreePath: worktreePath,
        revision: snapshot.baseRevision,
        entry: entry,
      );
      final afterResult = _readAfter(
        worktreePath: worktreePath,
        entry: entry,
      );
      final skipReason = _skipReason(before: beforeResult, after: afterResult);
      if (skipReason != null) {
        diffs.add(
          FileDiff.skipped(
            file: entry.file,
            reason: skipReason,
            status: entry.status,
          ),
        );
        continue;
      }

      final before = (beforeResult as _DiffFileContent).content;
      final after = (afterResult as _DiffFileContent).content;
      if (utf8.encode(before).length + utf8.encode(after).length > _maxFileContentBytes) {
        diffs.add(
          FileDiff.skipped(
            file: entry.file,
            reason: FileDiffSkipReason.tooLarge,
            status: entry.status,
          ),
        );
        continue;
      }

      final storedCounts = snapshot.lineCountsByFile[entry.file] ?? const (additions: 0, deletions: 0);
      final lineCounts = _lineCounts(
        status: entry.status,
        before: before,
        after: after,
        storedCounts: storedCounts,
        isUntracked: !snapshot.lineCountsByFile.containsKey(entry.file),
      );
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

  Future<_DiffFileReadResult> _readBefore({
    required String worktreePath,
    required String revision,
    required SessionDiffEntry entry,
  }) async {
    if (entry.status == FileDiffStatus.added) {
      return _DiffFileContent(content: "");
    }
    return switch (await _sessionDiffRepository.readFileAtRevision(
      worktreePath: worktreePath,
      revision: revision,
      file: entry.file,
      maxBytes: _maxFileContentBytes,
    )) {
      SessionDiffRevisionFileContent(:final content) => _DiffFileContent(content: content),
      SessionDiffRevisionFileBinary() => _DiffFileBinary(),
      SessionDiffRevisionFileTooLarge() => _DiffFileTooLarge(),
      SessionDiffRevisionFileReadFailure() => _DiffFileReadFailure(),
    };
  }

  _DiffFileReadResult _readAfter({
    required String worktreePath,
    required SessionDiffEntry entry,
  }) {
    if (entry.status == FileDiffStatus.deleted) {
      return _DiffFileContent(content: "");
    }
    return switch (_filesystemRepository.readBoundedTextFile(
      rootDirectoryPath: worktreePath,
      relativePath: entry.file,
      maxBytes: _maxFileContentBytes,
    )) {
      BoundedTextFileContent(:final content) => _DiffFileContent(content: content),
      BoundedTextFileMissing() => _DiffFileContent(content: ""),
      BoundedTextFileBinary() => _DiffFileBinary(),
      BoundedTextFileTooLarge() => _DiffFileTooLarge(),
      BoundedTextFileReadFailure() => _DiffFileReadFailure(),
    };
  }

  FileDiffSkipReason? _skipReason({
    required _DiffFileReadResult before,
    required _DiffFileReadResult after,
  }) {
    if (before is _DiffFileReadFailure || after is _DiffFileReadFailure) {
      return FileDiffSkipReason.readError;
    }
    if (before is _DiffFileTooLarge || after is _DiffFileTooLarge) {
      return FileDiffSkipReason.tooLarge;
    }
    if (before is _DiffFileBinary || after is _DiffFileBinary) {
      return FileDiffSkipReason.binary;
    }
    return null;
  }

  SessionDiffLineCounts _lineCounts({
    required FileDiffStatus? status,
    required String before,
    required String after,
    required SessionDiffLineCounts storedCounts,
    required bool isUntracked,
  }) {
    if (isUntracked && after.isNotEmpty) {
      return (additions: _countLines(content: after), deletions: 0);
    }
    if (status == FileDiffStatus.modified &&
        storedCounts.additions == 0 &&
        after.isNotEmpty &&
        before != after &&
        (storedCounts.deletions == 0 || !_isDeletionOnlyChange(before: before, after: after))) {
      return (
        additions: _countLines(content: after),
        deletions: storedCounts.deletions > 0 ? storedCounts.deletions : _countLines(content: before),
      );
    }
    return storedCounts;
  }

  int _countLines({required String content}) {
    if (content.isEmpty) return 0;
    return "\n".allMatches(content).length + (content.endsWith("\n") ? 0 : 1);
  }

  bool _isDeletionOnlyChange({required String before, required String after}) {
    if (after.isEmpty) return true;
    final beforeLines = _normalizedLines(content: before);
    final afterLines = _normalizedLines(content: after);
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

  List<String> _normalizedLines({required String content}) {
    return content.replaceAll("\r\n", "\n").split("\n").map((line) => line.replaceAll("\r", "")).toList();
  }
}
