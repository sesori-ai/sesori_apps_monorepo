import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "../repositories/project_repository.dart";
import "project_activity_service.dart";
import "project_initialization_service.dart";

sealed class const OpenProjectOutcome();

final class const OpenProjectSuccess({required this.project}) extends OpenProjectOutcome {
  final Project project;
}

final class const OpenProjectDirectoryNotFound() extends OpenProjectOutcome;

final class const OpenProjectPathNotDirectory() extends OpenProjectOutcome;

final class const OpenProjectGitChoiceRequired() extends OpenProjectOutcome;

/// Owns complete create, open, and hide workflows under one bridge-wide FIFO.
class ProjectMutationService({
    required FilesystemRepository filesystemRepository,
    required ProjectInitializationService projectInitializationService,
    required ProjectActivityService projectActivityService,
    required ProjectRepository projectRepository,
  }) {
  final FilesystemRepository _filesystemRepository;
  final ProjectInitializationService _projectInitializationService;
  final ProjectActivityService _projectActivityService;
  final ProjectRepository _projectRepository;

  Future<void> _tail = Future<void>.value();

  this : _filesystemRepository = filesystemRepository,
       _projectInitializationService = projectInitializationService,
       _projectActivityService = projectActivityService,
       _projectRepository = projectRepository;

  Future<Project> createProject({required String path}) {
    return _enqueue(() async {
      await _projectInitializationService.initializeProject(path: path);
      return _projectActivityService.openProject(path: path);
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

  Future<T> _enqueue<T>(Future<T> Function() workflow) {
    final result = _tail.then((_) => workflow());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
