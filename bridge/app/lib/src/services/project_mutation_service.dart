import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show ParallelLock;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "../repositories/project_repository.dart";
import "project_activity_service.dart";
import "project_initialization_service.dart";

sealed class const OpenProjectOutcome();

final class const OpenProjectSuccess({required final Project project}) extends OpenProjectOutcome;

final class const OpenProjectDirectoryNotFound() extends OpenProjectOutcome;

final class const OpenProjectPathNotDirectory() extends OpenProjectOutcome;

final class const OpenProjectGitChoiceRequired() extends OpenProjectOutcome;

/// Owns complete create, open, and hide workflows under one bridge-wide FIFO.
class ProjectMutationService({
  required final FilesystemRepository _filesystemRepository,
  required final ProjectInitializationService _projectInitializationService,
  required final ProjectActivityService _projectActivityService,
  required final ProjectRepository _projectRepository,
}) {
  final ParallelLock _lock = ParallelLock(maxParallelOperations: 1);

  Future<Project> createProject({required String path}) {
    return _enqueue(() async {
      await _projectInitializationService.initializeProject(path: path);
      return await _projectActivityService.openProject(path: path);
    });
  }

  Future<OpenProjectOutcome> openProject({
    required String path,
    required OpenProjectGitAction gitAction,
  }) {
    return _enqueue(() async {
      switch (_filesystemRepository.classifyPath(path: path)) {
        case FilesystemEntityKind.notFound:
          return const OpenProjectDirectoryNotFound();
        case FilesystemEntityKind.notDirectory:
          return const OpenProjectPathNotDirectory();
        case FilesystemEntityKind.directory:
          final preparation = await _projectInitializationService.prepareExistingProject(
            path: path,
            gitAction: gitAction,
          );
          switch (preparation) {
            case ExistingProjectPreparationOutcome.gitChoiceRequired:
              return const OpenProjectGitChoiceRequired();
            case ExistingProjectPreparationOutcome.ready:
              return OpenProjectSuccess(
                project: await _projectActivityService.openProject(path: path),
              );
          }
      }
    });
  }

  Future<void> hideProject({required String projectId}) {
    return _enqueue(() => _projectRepository.hideProject(projectId: projectId));
  }

  Future<T> _enqueue<T>(Future<T> Function() workflow) => _lock.use(operation: workflow);
}
