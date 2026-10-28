import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart"
    show
        FilePreviewResponse,
        FilesystemSuggestion,
        FilesystemSuggestions,
        maxFilePreviewTextBytes,
        maxTranscriptImageBytes;

import "../api/drive_roots_api.dart";
import "../api/filesystem_api.dart";
import "../foundation/filesystem_permission_validator.dart";

/// Thrown when a filesystem operation fails because the host OS denied access
/// (e.g. macOS Full Disk Access not granted to the application or terminal
/// running the bridge). Carries the [path] that could not be accessed.
class FilesystemPermissionDeniedException({required final String path}) implements Exception {
  @override
  String toString() => "FilesystemPermissionDeniedException: permission denied: $path";
}

/// Thrown when a directory that was expected to exist could not be found.
class FilesystemDirectoryNotFoundException({required final String path}) implements Exception {
  @override
  String toString() => "FilesystemDirectoryNotFoundException: directory not found: $path";
}

/// The kind of entity at a path, as resolved by [FilesystemRepository.classifyPath].
enum FilesystemEntityKind() { notFound, notDirectory, directory }

/// The outcome of preparing a directory for creation. [alreadyExists] covers
/// any entity occupying the target path, not only a directory.
enum CreatableDirectoryStatus() { creatable, parentMissing, alreadyExists }

sealed class BoundedTextFileReadResult();

class BoundedTextFileContent({required final String content}) extends BoundedTextFileReadResult;

class BoundedTextFileMissing() extends BoundedTextFileReadResult;

class BoundedTextFileBinary() extends BoundedTextFileReadResult;

class BoundedTextFileTooLarge() extends BoundedTextFileReadResult;

class BoundedTextFileReadFailure() extends BoundedTextFileReadResult;

/// Layer 2 aggregator over [FilesystemApi]. Owns the mapping from raw
/// `dart:io` results into shared models and the classification of
/// [FileSystemException]s into typed domain errors. Handlers consume the typed
/// results/exceptions and map them to HTTP statuses.
class FilesystemRepository({
    required final FilesystemApi _filesystemApi,
    required final FilesystemPermissionValidator _permissionValidator,
    required final DriveRootsApi _driveRootsApi,
  }) {
  static const _driveProbeTimeout = Duration(seconds: 2);

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

  /// Image extensions a file preview returns as an image, with their MIME types.
  static const _previewImageMimeTypes = <String, String>{
    "png": "image/png",
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "gif": "image/gif",
    "webp": "image/webp",
  };

  bool directoryExists({required String path}) {
    return _guard(path: path, () => _filesystemApi.directoryExists(path));
  }

  /// The host directory shown when the client has not selected a prefix yet.
  String get defaultBrowsePath {
    return resolveUserHomeDirectory(environment: _filesystemApi.environment) ?? _filesystemApi.currentDirectoryPath();
  }

  /// The drives the folder browser lists beside Home: a Windows host's mounted
  /// drive roots, such as `C:\`, in letter order, or the writable disks and
  /// partitions mounted in a macOS or Linux host's usual mount folders, in
  /// path order. Empty when the mount table is unreadable.
  ///
  /// Every candidate is probed at once, and a probe that fails or has not
  /// answered within [_driveProbeTimeout] counts as unmounted, so an
  /// inaccessible or disconnected network drive cannot hold up or fail the
  /// listing it rides on.
  Future<List<String>> listDriveRoots() async {
    final List<String> candidates;
    try {
      candidates = await _driveRootsApi.listCandidates();
    } on Exception catch (error, stackTrace) {
      Log.w("FilesystemRepository: omitting mounted drives after a failed mount-table read", error, stackTrace);
      return const [];
    }
    final mounted = await Future.wait([for (final root in candidates) _probeDrive(root: root)]);
    return [
      for (final (index, root) in candidates.indexed)
        if (mounted[index]) root,
    ];
  }

  Future<bool> _probeDrive({required String root}) async {
    try {
      return await _filesystemApi.directoryExistsAsync(root).timeout(_driveProbeTimeout, onTimeout: () => false);
    } on FileSystemException catch (error, stackTrace) {
      Log.w("FilesystemRepository: omitting drive $root after a failed probe", error, stackTrace);
      return false;
    }
  }

  /// The folder browser's listing: the children of [prefix], or, for the
  /// browser's opening request without a prefix, the children of
  /// [defaultBrowsePath] together with the host's drives. Only the
  /// opening request carries the drives: they do not change while it browses.
  ///
  /// Throws like [listSuggestions].
  Future<FilesystemSuggestions> listBrowserSuggestions({required String? prefix, required int maxResults}) async {
    if (prefix != null) return listSuggestions(prefix: prefix, maxResults: maxResults);
    final suggestions = listSuggestions(prefix: defaultBrowsePath, maxResults: maxResults);
    return suggestions.copyWith(driveRoots: await listDriveRoots());
  }

  bool isKnownBinaryFile({required String relativePath}) {
    return _binaryExtensions.contains(_extensionOf(path: relativePath));
  }

  /// The lowercase extension of [path] without its dot, or null without one.
  String? _extensionOf({required String path}) {
    final extension = p.extension(path).toLowerCase();
    return extension.isEmpty ? null : extension.substring(1);
  }

  /// A read-only preview of the file at [absolutePath], following links: its
  /// text up to [maxFilePreviewTextBytes], or a known image up to
  /// [maxTranscriptImageBytes].
  ///
  /// Rethrows a [FileSystemException] that is neither a permission denial nor
  /// a missing file.
  FilePreviewResponse readPreviewFile({required String absolutePath}) {
    try {
      final entityType = _filesystemApi.entityType(absolutePath);
      if (entityType == FileSystemEntityType.notFound) return const FilePreviewResponse.missing();
      if (entityType == FileSystemEntityType.directory ||
          (entityType == FileSystemEntityType.link && _filesystemApi.directoryExists(absolutePath))) {
        return const FilePreviewResponse.unsupported();
      }

      final extension = _extensionOf(path: absolutePath);
      final imageMime = _previewImageMimeTypes[extension];
      if (imageMime != null) {
        final bytes = _filesystemApi.readFilePrefix(path: absolutePath, maxBytes: maxTranscriptImageBytes);
        if (bytes.length > maxTranscriptImageBytes) return const FilePreviewResponse.tooLarge();
        return FilePreviewResponse.image(mime: imageMime, base64: base64Encode(bytes), byteLength: bytes.length);
      }
      if (_binaryExtensions.contains(extension)) return const FilePreviewResponse.unsupported();

      final bytes = _filesystemApi.readFilePrefix(path: absolutePath, maxBytes: maxFilePreviewTextBytes);
      if (bytes.length > maxFilePreviewTextBytes) return const FilePreviewResponse.tooLarge();
      if (bytes.contains(0)) return const FilePreviewResponse.unsupported();
      try {
        return FilePreviewResponse.text(content: utf8.decode(bytes));
      } on FormatException {
        return const FilePreviewResponse.unsupported();
      }
    } on FileSystemException catch (error) {
      if (_permissionValidator.isPermissionDenied(error)) return const FilePreviewResponse.denied();
      if (_permissionValidator.isFileMissing(error)) return const FilePreviewResponse.missing();
      rethrow;
    }
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
      // A link to a folder opens as that folder on macOS and Linux, where the
      // project then stores the folder it resolves to. Windows stores a path
      // as spelled, so a link there would open beside its target as a second
      // project; it stays refused.
      final isLinkedDirectory =
          type == FileSystemEntityType.link && !Platform.isWindows && _filesystemApi.directoryExists(path);
      if (type != FileSystemEntityType.directory && !isLinkedDirectory) {
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
  /// Anything already occupying [path] — a directory, a file, or a link —
  /// reports [CreatableDirectoryStatus.alreadyExists]: the name is taken either
  /// way, and creation would fail on all of them. Reporting only the directory
  /// case would leave a file with that name to surface later as a generic
  /// creation failure rather than the name conflict it is.
  ///
  /// Throws [FilesystemPermissionDeniedException] on an OS permission denial.
  CreatableDirectoryStatus checkCreatableDirectory({required String path}) {
    return _guard(path: path, () {
      if (!_filesystemApi.directoryExists(_filesystemApi.parentPath(path))) {
        return CreatableDirectoryStatus.parentMissing;
      }
      if (_filesystemApi.entityType(path) != FileSystemEntityType.notFound) {
        return CreatableDirectoryStatus.alreadyExists;
      }
      return CreatableDirectoryStatus.creatable;
    });
  }

  /// Creates the directory at [path].
  ///
  /// Throws [FilesystemPermissionDeniedException] on an OS permission denial.
  void createDirectory({required String path}) {
    _guard(path: path, () {
      _filesystemApi.createDirectory(path);
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
