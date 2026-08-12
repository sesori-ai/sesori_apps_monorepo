import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:crypto/crypto.dart";
import "package:meta/meta.dart";
import "package:path/path.dart" as path;

import "data_directory_hardening.dart";

final class AttachmentStorageScope {
  final String pluginId;
  final String backendSessionId;

  const AttachmentStorageScope({
    required this.pluginId,
    required this.backendSessionId,
  });
}

enum AttachmentThumbnailFormat {
  jpeg,
  png;

  String get extension => switch (this) {
    AttachmentThumbnailFormat.jpeg => "jpg",
    AttachmentThumbnailFormat.png => "png",
  };

  String get mime => switch (this) {
    AttachmentThumbnailFormat.jpeg => "image/jpeg",
    AttachmentThumbnailFormat.png => "image/png",
  };
}

/// Raw file boundary for attachment bytes kept out of the database.
///
/// Files are content-addressed by the sha256 of their decoded bytes under a
/// durable plugin/backend-session scope shared by every bridge data directory.
/// Their lifetime is manual because independent databases may reference the
/// same scope.
class AttachmentSpillStorage {
  AttachmentSpillStorage({required String directoryPath}) : _directoryPath = directoryPath;

  final String _directoryPath;

  /// Creates the spill root with its intended permissions, so a fresh data
  /// installation has the same shape as one that has stored attachments.
  void ensureDirectory() => createHardenedDirectory(directoryPath: _directoryPath);

  /// Writes [bytes] if absent and returns their content address.
  ///
  /// The write is atomic on every platform — bytes land in a temporary file
  /// that is renamed into place — so an interrupted write can never leave a
  /// partial file that a later `existsSync` check would trust.
  Future<String> write({required AttachmentStorageScope scope, required Uint8List bytes}) async {
    final digest = sha256.convert(bytes).toString();
    final file = File(_filePath(scope: scope, digest: digest));
    if (file.existsSync()) return digest;

    await _ensureScopeDirectory(scope: scope);

    final temporary = File("${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp");
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await hardenPath(targetPath: temporary.path, mode: ownerOnlyFileMode);
      await temporary.rename(file.path);
    } on FileSystemException {
      // Windows refuses to rename onto an existing file. Content addressing
      // makes the winner of that race byte-identical, so an existing target is
      // success — but only a target that really holds these bytes. Anything
      // else is a genuine write failure and must surface.
      if (!await _holdsDigest(file: file, digest: digest)) rethrow;
    } finally {
      if (temporary.existsSync()) {
        temporary.deleteSync();
      }
    }
    return digest;
  }

  /// The stored bytes, or null when the spill file is gone.
  Future<Uint8List?> read({required AttachmentStorageScope scope, required String digest}) async {
    if (!isContentAddress(digest: digest)) {
      throw ArgumentError.value(digest, "digest", "not a sha256 content address");
    }
    final file = File(_filePath(scope: scope, digest: digest));
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  Future<({Uint8List bytes, AttachmentThumbnailFormat format})?> readThumbnail({
    required AttachmentStorageScope scope,
    required String digest,
  }) async {
    if (!isContentAddress(digest: digest)) {
      throw ArgumentError.value(digest, "digest", "not a sha256 content address");
    }
    for (final format in AttachmentThumbnailFormat.values) {
      final file = File(_thumbnailPath(scope: scope, digest: digest, format: format));
      if (file.existsSync()) return (bytes: await file.readAsBytes(), format: format);
    }
    return null;
  }

  /// Atomically writes a derived rendition beside its source original.
  ///
  /// The session directory is deliberately not created here. A thumbnail for a
  /// purged source must not recreate that source's retention root.
  Future<bool> writeThumbnail({
    required AttachmentStorageScope scope,
    required String digest,
    required AttachmentThumbnailFormat format,
    required Uint8List bytes,
  }) async {
    if (!isContentAddress(digest: digest)) {
      throw ArgumentError.value(digest, "digest", "not a sha256 content address");
    }
    final file = File(_thumbnailPath(scope: scope, digest: digest, format: format));
    if (file.existsSync()) return true;
    if (!file.parent.existsSync()) return false;

    final temporary = File("${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp");
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await hardenPath(targetPath: temporary.path, mode: ownerOnlyFileMode);
      await temporary.rename(file.path);
    } on FileSystemException {
      if (!file.existsSync()) rethrow;
    } finally {
      if (temporary.existsSync()) temporary.deleteSync();
    }
    return true;
  }

  static Future<bool> _holdsDigest({required File file, required String digest}) async {
    if (!file.existsSync()) return false;
    try {
      return sha256.convert(await file.readAsBytes()).toString() == digest;
    } on FileSystemException {
      return false;
    }
  }

  /// Guards the file boundary: only names this class generates may address a
  /// spill file, so a malformed reference can never escape the directory.
  static bool isContentAddress({required String digest}) {
    return digest.length == 64 && RegExp(r"^[0-9a-f]{64}$").hasMatch(digest);
  }

  @visibleForTesting
  String scopeDirectoryPath({required AttachmentStorageScope scope}) => _scopeDirectoryPath(scope: scope);

  String _scopeDirectoryPath({required AttachmentStorageScope scope}) =>
      path.join(_pluginDirectoryPath(scope: scope), _segment(id: scope.backendSessionId));

  Future<void> _ensureScopeDirectory({required AttachmentStorageScope scope}) async {
    final pluginDirectory = Directory(_pluginDirectoryPath(scope: scope));
    await pluginDirectory.create(recursive: true);
    await hardenPath(targetPath: pluginDirectory.path, mode: ownerOnlyDirectoryMode);
    final scopeDirectory = Directory(_scopeDirectoryPath(scope: scope));
    await scopeDirectory.create();
    await hardenPath(targetPath: scopeDirectory.path, mode: ownerOnlyDirectoryMode);
  }

  String _pluginDirectoryPath({required AttachmentStorageScope scope}) =>
      path.join(_directoryPath, _segment(id: scope.pluginId));

  String _filePath({required AttachmentStorageScope scope, required String digest}) =>
      path.join(_scopeDirectoryPath(scope: scope), digest);

  String _thumbnailPath({
    required AttachmentStorageScope scope,
    required String digest,
    required AttachmentThumbnailFormat format,
  }) => path.join(_scopeDirectoryPath(scope: scope), "$digest.thumbnail-v1.${format.extension}");

  /// Plugin and backend identifiers address directories, so encode rather than
  /// trust their shape.
  String _segment({required String id}) => base64Url.encode(utf8.encode(id));
}
