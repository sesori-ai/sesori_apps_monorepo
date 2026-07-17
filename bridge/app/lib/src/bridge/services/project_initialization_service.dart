import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show OpenProjectGitAction;

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

/// Thrown when Git setup fails for a newly created project directory.
class ProjectGitSetupException implements Exception {
  final String path;
  final String operation;
  final Object? cause;

  ProjectGitSetupException({
    required this.path,
    required this.operation,
    required this.cause,
  });

  @override
  String toString() => "ProjectGitSetupException: $operation failed: $path";
}

enum ExistingProjectPreparationOutcome { ready, gitChoiceRequired }

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
  /// [ProjectGitSetupException], or [FilesystemPermissionDeniedException] on
  /// the corresponding failures. Git initialization, staging, and the initial
  /// commit must all succeed so the project supports dedicated worktrees.
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

    try {
      await _initializeGitProject(path: path);
    } on Object catch (error, stackTrace) {
      _cleanupCreatedProject(path: path);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<ExistingProjectPreparationOutcome> prepareExistingProject({
    required String path,
    required OpenProjectGitAction gitAction,
  }) async {
    if (gitAction == OpenProjectGitAction.openWithoutGit) {
      return ExistingProjectPreparationOutcome.ready;
    }

    final isGitInitialized = await _worktreeRepository.isGitInitialized(projectPath: path);
    final isInsideGitWorkTree = isGitInitialized || await _worktreeRepository.isInsideGitWorkTree(projectPath: path);
    switch (gitAction) {
      case OpenProjectGitAction.promptIfNeeded:
        if (!isInsideGitWorkTree) {
          return ExistingProjectPreparationOutcome.gitChoiceRequired;
        }
      case OpenProjectGitAction.initializeGit:
        if (isInsideGitWorkTree && !isGitInitialized) {
          break;
        }
        final hasCommit = isInsideGitWorkTree && await _worktreeRepository.hasAtLeastOneCommit(projectPath: path);
        if (!hasCommit) {
          try {
            await _initializeGitProject(path: path);
          } on Object catch (error, stackTrace) {
            Log.w("ProjectInitializationService: Git setup incomplete for $path", error, stackTrace);
          }
        }
      case OpenProjectGitAction.openWithoutGit:
        return ExistingProjectPreparationOutcome.ready;
    }
    return ExistingProjectPreparationOutcome.ready;
  }

  Future<void> _initializeGitProject({required String path}) async {
    await _requireGitStep(
      path: path,
      operation: "git init",
      run: () => _worktreeRepository.initRepository(path: path),
    );

    _filesystemRepository.ensureGitignoreEntry(projectPath: path, entry: _gitignoreEntry);

    await _requireGitStep(
      path: path,
      operation: "git add",
      run: () => _worktreeRepository.stageAll(projectPath: path),
    );
    await _requireGitStep(
      path: path,
      operation: "initial commit",
      run: () => _worktreeRepository.commitAll(
        projectPath: path,
        message: _initialCommitMessage,
      ),
    );
  }

  Future<void> _requireGitStep({
    required String path,
    required String operation,
    required Future<bool> Function() run,
  }) async {
    try {
      if (await run()) return;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ProjectGitSetupException(path: path, operation: operation, cause: error),
        stackTrace,
      );
    }
    throw ProjectGitSetupException(path: path, operation: operation, cause: null);
  }

  void _cleanupCreatedProject({required String path}) {
    try {
      final entries = _filesystemRepository.listDirectoryEntryNames(path: path);
      const createdEntries = {".git", ".gitignore"};
      if (!entries.every(createdEntries.contains)) {
        Log.w("ProjectInitializationService: leaving failed project directory with unknown content: $path");
        return;
      }
      _filesystemRepository.deleteDirectoryRecursively(path: path);
    } on Object catch (error, stackTrace) {
      Log.w("ProjectInitializationService: failed to clean up $path", error, stackTrace);
    }
  }
}
