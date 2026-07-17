import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
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

sealed class BoundedTextFileReadResult {}

class BoundedTextFileContent extends BoundedTextFileReadResult {
  final String content;

  BoundedTextFileContent({required this.content});
}

class BoundedTextFileMissing extends BoundedTextFileReadResult {}

class BoundedTextFileBinary extends BoundedTextFileReadResult {}

class BoundedTextFileTooLarge extends BoundedTextFileReadResult {}

class BoundedTextFileReadFailure extends BoundedTextFileReadResult {}

/// Layer 2 aggregator over [FilesystemApi]. Owns the mapping from raw
/// `dart:io` results into shared models and the classification of
/// [FileSystemException]s into typed domain errors. Handlers consume the typed
/// results/exceptions and map them to HTTP statuses.
class FilesystemRepository {
  static const _binaryExtensions = <String>{
    "png",
    "jpg",
    "jpeg",
    "gif",
    "ico",
    "webp",
    "bmp",
    "tiff",
    "woff",
    "woff2",
    "ttf",
    "otf",
    "eot",
    "zip",
    "tar",
    "gz",
    "bz2",
    "xz",
    "7z",
    "rar",
    "mp3",
    "mp4",
    "wav",
    "ogg",
    "webm",
    "avi",
    "mov",
    "flac",
    "pdf",
    "doc",
    "docx",
    "xls",
    "xlsx",
    "ppt",
    "pptx",
    "exe",
    "dll",
    "so",
    "dylib",
    "bin",
    "wasm",
    "class",
    "pyc",
    "sqlite",
    "db",
  };

  final FilesystemApi _filesystemApi;
  final FilesystemPermissionValidator _permissionValidator;

  FilesystemRepository({
    required FilesystemApi filesystemApi,
    required FilesystemPermissionValidator permissionValidator,
  }) : _filesystemApi = filesystemApi,
       _permissionValidator = permissionValidator;

  bool directoryExists({required String path}) {
    return _guard(path: path, () => _filesystemApi.directoryExists(path));
  }

  /// The host directory shown when the client has not selected a prefix yet.
  String get defaultBrowsePath {
    final home = _filesystemApi.environmentValue("HOME");
    if (home != null && home.isNotEmpty) return home;
    final userProfile = _filesystemApi.environmentValue("USERPROFILE");
    if (userProfile != null && userProfile.isNotEmpty) return userProfile;
    return _filesystemApi.currentDirectoryPath();
  }

  bool isKnownBinaryFile({required String relativePath}) {
    final extension = p.extension(relativePath).toLowerCase();
    return extension.isNotEmpty && _binaryExtensions.contains(extension.substring(1));
  }

  BoundedTextFileReadResult readBoundedTextFile({
    required String rootDirectoryPath,
    required String relativePath,
    required int maxBytes,
  }) {
    if (isKnownBinaryFile(relativePath: relativePath)) {
      return BoundedTextFileBinary();
    }

    final absoluteRootPath = p.normalize(p.absolute(rootDirectoryPath));
    final candidatePath = p.normalize(p.absolute(p.join(rootDirectoryPath, relativePath)));
    if (candidatePath != absoluteRootPath && !p.isWithin(absoluteRootPath, candidatePath)) {
      return BoundedTextFileReadFailure();
    }

    try {
      final entityType = _filesystemApi.entityType(candidatePath);
      if (entityType == FileSystemEntityType.link) {
        return BoundedTextFileReadFailure();
      }
      if (entityType == FileSystemEntityType.notFound) {
        return BoundedTextFileMissing();
      }

      final resolvedPath = p.normalize(_filesystemApi.resolveFilePath(candidatePath));
      final resolvedRootPath = p.normalize(_filesystemApi.resolveDirectoryPath(rootDirectoryPath));
      if (resolvedPath != resolvedRootPath && !p.isWithin(resolvedRootPath, resolvedPath)) {
        return BoundedTextFileReadFailure();
      }

      final bytes = _filesystemApi.readFilePrefix(
        path: candidatePath,
        maxBytes: maxBytes,
      );
      if (bytes.length > maxBytes) {
        return BoundedTextFileTooLarge();
      }
      if (bytes.contains(0)) {
        return BoundedTextFileBinary();
      }
      try {
        return BoundedTextFileContent(content: utf8.decode(bytes));
      } on FormatException {
        return BoundedTextFileBinary();
      }
    } on FileSystemException {
      return BoundedTextFileReadFailure();
    }
  }

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

      // Filter, sort, and truncate by name FIRST, then probe `.git` only for
      // the selected entries. Probing every child up front would stat
      // directories that will never be returned and, because the probe runs
      // inside _guard, an unreadable out-of-page child could 403 the whole
      // listing.
      final selected =
          _filesystemApi
              .listDirectories(prefix)
              .map((d) => (path: d.path, name: p.basename(d.path)))
              .where((e) => !e.name.startsWith("."))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      final suggestions = selected
          .take(maxResults)
          .map(
            (e) =>
                FilesystemSuggestion(path: e.path, name: e.name, isGitRepo: _filesystemApi.gitDirectoryExists(e.path)),
          )
          .toList();

      return FilesystemSuggestions(data: suggestions, path: prefix);
    });
  }

  /// Classifies what exists at [path].
  ///
  /// Throws [FilesystemPermissionDeniedException] on an OS permission denial.
  /// A directory that can be stat'ed but not read (e.g. macOS Full Disk
  /// Access/TCC denial) is probed here so the open-project path surfaces the
  /// same actionable permission error as browsing/creation, instead of
  /// returning [FilesystemEntityKind.directory] and failing later as a generic
  /// upstream error.
  FilesystemEntityKind classifyPath({required String path}) {
    return _guard(path: path, () {
      final type = _filesystemApi.entityType(path);
      if (type == FileSystemEntityType.notFound) {
        return FilesystemEntityKind.notFound;
      }
      if (type != FileSystemEntityType.directory) {
        return FilesystemEntityKind.notDirectory;
      }
      // Probe readability: a stat-only success is not enough to open the
      // directory as a project. A permission denial here is translated to
      // FilesystemPermissionDeniedException by _guard.
      _filesystemApi.listDirectories(path);
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
    final gitignorePath = p.join(projectPath, ".gitignore");
    _guard(path: gitignorePath, () {
      final content = _filesystemApi.readFileIfExists(gitignorePath) ?? "";
      if (!const LineSplitter().convert(content).contains(entry)) {
        final separator = content.isEmpty || content.endsWith("\n") ? "" : "\n";
        _filesystemApi.appendToFile(gitignorePath, "$separator$entry\n");
      }
    });
  }

  Set<String> listDirectoryEntryNames({required String path}) {
    return _guard(path: path, () => _filesystemApi.listEntryNames(path).toSet());
  }

  void deleteDirectoryRecursively({required String path}) {
    _guard(path: path, () => _filesystemApi.deleteDirectoryRecursively(path));
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
