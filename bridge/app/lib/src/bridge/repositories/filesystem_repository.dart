import "dart:io";

import "package:sesori_shared/sesori_shared.dart" show FilesystemSuggestion, FilesystemSuggestions;

import "../api/filesystem_api.dart";
import "../foundation/filesystem_permission_validator.dart";

/// Thrown when a filesystem operation fails because the host OS denied access
/// (e.g. macOS Full Disk Access not granted to the terminal running the
/// bridge). Carries the [path] that could not be accessed.
class FilesystemPermissionDeniedException implements Exception {
  final String path;

  FilesystemPermissionDeniedException({required this.path});

  @override
  String toString() => "FilesystemPermissionDeniedException: permission denied: $path";
}

/// Thrown when a directory that was expected to exist could not be found.
class FilesystemDirectoryNotFoundException implements Exception {
  final String path;

  FilesystemDirectoryNotFoundException({required this.path});

  @override
  String toString() => "FilesystemDirectoryNotFoundException: directory not found: $path";
}

/// The kind of entity at a path, as resolved by [FilesystemRepository.classifyPath].
enum FilesystemEntityKind { notFound, notDirectory, directory }

/// The outcome of preparing a directory for project creation.
enum CreatableDirectoryStatus { creatable, parentMissing, alreadyExists }

/// Layer 2 aggregator over [FilesystemApi]. Owns the mapping from raw
/// `dart:io` results into shared models and the classification of
/// [FileSystemException]s into typed domain errors. Handlers consume the typed
/// results/exceptions and map them to HTTP statuses.
class FilesystemRepository {
  final FilesystemApi _filesystemApi;
  final FilesystemPermissionValidator _permissionValidator;

  FilesystemRepository({
    required FilesystemApi filesystemApi,
    required FilesystemPermissionValidator permissionValidator,
  }) : _filesystemApi = filesystemApi,
       _permissionValidator = permissionValidator;

  /// Lists child directories of [prefix], skipping dotfiles, mapped to shared
  /// [FilesystemSuggestion]s sorted by name.
  ///
  /// Throws [FilesystemPermissionDeniedException] on an OS permission denial,
  /// [FilesystemDirectoryNotFoundException] when [prefix] does not exist.
  FilesystemSuggestions listSuggestions({required String prefix, required int maxResults}) {
    return _guard(path: prefix, () {
      if (!_filesystemApi.directoryExists(prefix)) {
        throw FilesystemDirectoryNotFoundException(path: prefix);
      }

      final entries =
          _filesystemApi
              .listDirectories(prefix)
              .where((d) => !d.path.split("/").last.startsWith("."))
              .take(maxResults)
              .map((d) {
                final name = d.path.split("/").last;
                final isGitRepo = _filesystemApi.gitDirectoryExists(d.path);
                return FilesystemSuggestion(path: d.path, name: name, isGitRepo: isGitRepo);
              })
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      return FilesystemSuggestions(data: entries);
    });
  }

  /// Classifies what exists at [path].
  ///
  /// Throws [FilesystemPermissionDeniedException] on an OS permission denial.
  FilesystemEntityKind classifyPath({required String path}) {
    return _guard(path: path, () {
      final type = _filesystemApi.entityType(path);
      if (type == FileSystemEntityType.notFound) {
        return FilesystemEntityKind.notFound;
      }
      if (type != FileSystemEntityType.directory) {
        return FilesystemEntityKind.notDirectory;
      }
      return FilesystemEntityKind.directory;
    });
  }

  /// Checks whether [path] can be created as a new project directory.
  ///
  /// Throws [FilesystemPermissionDeniedException] on an OS permission denial.
  CreatableDirectoryStatus checkCreatableDirectory({required String path}) {
    return _guard(path: path, () {
      if (!_filesystemApi.directoryExists(_filesystemApi.parentPath(path))) {
        return CreatableDirectoryStatus.parentMissing;
      }
      if (_filesystemApi.directoryExists(path)) {
        return CreatableDirectoryStatus.alreadyExists;
      }
      return CreatableDirectoryStatus.creatable;
    });
  }

  /// Creates the project directory at [path].
  ///
  /// Throws [FilesystemPermissionDeniedException] on an OS permission denial.
  void createProjectDirectory({required String path}) {
    _guard(path: path, () {
      _filesystemApi.createDirectory(path);
    });
  }

  /// Idempotently ensures the `.gitignore` at [projectPath] contains [entry].
  ///
  /// Throws [FilesystemPermissionDeniedException] on an OS permission denial.
  void ensureGitignoreEntry({required String projectPath, required String entry}) {
    final gitignorePath = "$projectPath/.gitignore";
    _guard(path: gitignorePath, () {
      final content = _filesystemApi.readFileIfExists(gitignorePath) ?? "";
      if (!content.contains(entry)) {
        _filesystemApi.appendToFile(gitignorePath, "$entry\n");
      }
    });
  }

  /// Runs [action], translating any [FileSystemException] permission denial
  /// into a [FilesystemPermissionDeniedException] for [path]. Non-permission
  /// failures rethrow unchanged for the caller to map to a generic error.
  T _guard<T>(T Function() action, {required String path}) {
    try {
      return action();
    } on FileSystemException catch (error) {
      if (_permissionValidator.isPermissionDenied(error)) {
        throw FilesystemPermissionDeniedException(path: path);
      }
      rethrow;
    }
  }
}
