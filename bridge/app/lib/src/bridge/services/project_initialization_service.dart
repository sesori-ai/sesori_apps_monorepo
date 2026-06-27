import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/filesystem_repository.dart";
import "../repositories/worktree_repository.dart";

/// Thrown when project directory creation cannot proceed because the target
/// already exists.
class ProjectDirectoryExistsException implements Exception {
  final String path;

  ProjectDirectoryExistsException({required this.path});

  @override
  String toString() => "ProjectDirectoryExistsException: directory already exists: $path";
}

/// Thrown when the target's parent directory does not exist.
class ProjectParentMissingException implements Exception {
  final String path;

  ProjectParentMissingException({required this.path});

  @override
  String toString() => "ProjectParentMissingException: parent directory does not exist: $path";
}

/// Thrown when `git init` fails for a newly created project directory.
class ProjectGitInitException implements Exception {
  final String path;

  ProjectGitInitException({required this.path});

  @override
  String toString() => "ProjectGitInitException: git init failed: $path";
}

/// Layer 3 service that owns the "create a new project from a directory path"
/// flow: create the directory, initialize git, write the `.worktrees/`
/// `.gitignore` entry, then stage and commit an initial revision.
///
/// Decisions and orchestration live here; all filesystem and git execution is
/// delegated to repositories. On a macOS permission denial the underlying
/// [FilesystemPermissionDeniedException] propagates unchanged so the handler
/// can surface an actionable message.
class ProjectInitializationService {
  static const String _gitignoreEntry = ".worktrees/";
  static const String _initialCommitMessage = "Initial commit";

  final WorktreeRepository _worktreeRepository;
  final FilesystemRepository _filesystemRepository;

  ProjectInitializationService({
    required WorktreeRepository worktreeRepository,
    required FilesystemRepository filesystemRepository,
  }) : _worktreeRepository = worktreeRepository,
       _filesystemRepository = filesystemRepository;

  /// Creates and initializes a new git project at [path].
  ///
  /// Throws [ProjectParentMissingException], [ProjectDirectoryExistsException],
  /// [ProjectGitInitException], or [FilesystemPermissionDeniedException] on the
  /// corresponding failures. Staging and the initial commit are best-effort: a
  /// failure there is logged but does not abort creation (the directory is a
  /// valid, initialized repository regardless).
  Future<void> initializeProject({required String path}) async {
    final status = _filesystemRepository.checkCreatableDirectory(path: path);
    switch (status) {
      case CreatableDirectoryStatus.parentMissing:
        throw ProjectParentMissingException(path: path);
      case CreatableDirectoryStatus.alreadyExists:
        throw ProjectDirectoryExistsException(path: path);
      case CreatableDirectoryStatus.creatable:
        break;
    }

    _filesystemRepository.createProjectDirectory(path: path);

    // git init must succeed for the project to be usable, so a non-zero exit
    // OR a thrown execution error both become the typed failure the handler
    // maps to 500.
    bool initialized;
    try {
      initialized = await _worktreeRepository.initRepository(path: path);
    } on Object catch (error, stackTrace) {
      Log.w("ProjectInitializationService: git init threw for $path", error, stackTrace);
      throw ProjectGitInitException(path: path);
    }
    if (!initialized) {
      throw ProjectGitInitException(path: path);
    }

    _filesystemRepository.ensureGitignoreEntry(projectPath: path, entry: _gitignoreEntry);

    // Staging and the initial commit are best-effort: a non-zero exit OR a
    // thrown execution error is logged and swallowed, since the directory is a
    // valid initialized repository regardless.
    if (!await _stageBestEffort(path: path)) {
      return;
    }
    await _commitBestEffort(path: path);
  }

  Future<bool> _stageBestEffort({required String path}) async {
    try {
      if (!await _worktreeRepository.stageAll(projectPath: path)) {
        Log.w("ProjectInitializationService: git add failed for $path");
        return false;
      }
      return true;
    } on Object catch (error, stackTrace) {
      Log.w("ProjectInitializationService: git add threw for $path", error, stackTrace);
      return false;
    }
  }

  Future<void> _commitBestEffort({required String path}) async {
    try {
      final committed = await _worktreeRepository.commitAll(
        projectPath: path,
        message: _initialCommitMessage,
      );
      if (!committed) {
        Log.w("ProjectInitializationService: initial commit failed for $path");
      }
    } on Object catch (error, stackTrace) {
      Log.w("ProjectInitializationService: initial commit threw for $path", error, stackTrace);
    }
  }
}
