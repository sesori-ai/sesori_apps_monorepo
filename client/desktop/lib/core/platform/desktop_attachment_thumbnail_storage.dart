import "dart:io";
import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_dart_core/sesori_dart_core.dart";

import "desktop_temporary_directory_client.dart";

/// Desktop app-private cache for validated message-image thumbnails.
@LazySingleton(as: AttachmentThumbnailStorage)
class DesktopAttachmentThumbnailStorage({
  required final DesktopTemporaryDirectoryClient temporaryDirectoryClient,
}) implements AttachmentThumbnailStorage {
  static const _rootName = "attachment_thumbnails";
  static var _temporaryFileSequence = 0;
  static final Set<String> _activeTemporaryPaths = {};

  final DesktopTemporaryDirectoryClient _temporaryDirectoryClient = temporaryDirectoryClient;

  @override
  Future<Uint8List?> read({required String scope, required String key}) async {
    final file = await _file(scope: scope, key: key);
    try {
      return await file.readAsBytes();
    } on PathNotFoundException {
      return null;
    }
  }

  @override
  Future<void> write({
    required String scope,
    required String key,
    required Uint8List bytes,
  }) async {
    final file = await _file(scope: scope, key: key);
    await file.parent.create(recursive: true);
    final temporaryFile = File(path.join(file.parent.path, ".tmp-${_temporaryFileSequence++}"));
    _activeTemporaryPaths.add(temporaryFile.path);
    try {
      await temporaryFile.writeAsBytes(bytes, flush: true);
      await temporaryFile.rename(file.path);
    } finally {
      _activeTemporaryPaths.remove(temporaryFile.path);
      try {
        await temporaryFile.delete();
      } on PathNotFoundException {
        // A successful rename already removed the temporary path.
      }
    }
  }

  @override
  Future<List<AttachmentThumbnailMetadata>> listMetadata({required String scope}) async {
    final directory = await _scopeDirectory(scope: scope);
    try {
      final metadata = <AttachmentThumbnailMetadata>[];
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        if (path.basename(entity.path).startsWith(".tmp-")) {
          if (!_activeTemporaryPaths.contains(entity.path)) {
            try {
              await entity.delete();
            } on PathNotFoundException {
              // Another listing or write cleanup already removed it.
            } on Object catch (cause, stackTrace) {
              logw("Failed to delete abandoned desktop message thumbnail temporary file", cause, stackTrace);
            }
          }
          continue;
        }
        late final FileStat stat;
        try {
          // Keep filesystem work asynchronous on the UI isolate.
          // ignore: avoid_slow_async_io
          stat = await entity.stat();
        } on PathNotFoundException {
          continue;
        }
        if (stat.type == FileSystemEntityType.notFound) continue;
        metadata.add(
          AttachmentThumbnailMetadata(
            key: path.basename(entity.path),
            sizeBytes: stat.size,
            modifiedAt: stat.modified,
          ),
        );
      }
      return metadata;
    } on PathNotFoundException {
      return const [];
    }
  }

  @override
  Future<void> delete({required String scope, required String key}) async {
    final file = await _file(scope: scope, key: key);
    try {
      await file.delete();
    } on PathNotFoundException {
      return;
    }
  }

  @override
  Future<void> deleteScope({required String scope}) async {
    final directory = await _scopeDirectory(scope: scope);
    try {
      await directory.delete(recursive: true);
    } on PathNotFoundException {
      return;
    }
  }

  Future<Directory> _scopeDirectory({required String scope}) async {
    _validateSegment(value: scope, name: "scope");
    final temporaryDirectory = await _temporaryDirectoryClient.directory;
    return Directory(path.join(temporaryDirectory.path, _rootName, scope));
  }

  Future<File> _file({required String scope, required String key}) async {
    _validateSegment(value: key, name: "key");
    final directory = await _scopeDirectory(scope: scope);
    return File(path.join(directory.path, key));
  }

  void _validateSegment({required String value, required String name}) {
    if (value.isEmpty || value == "." || value == ".." || value.contains("/") || value.contains(r"\")) {
      throw ArgumentError.value(value, name, "must be one safe path segment");
    }
  }
}
