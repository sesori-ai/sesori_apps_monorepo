import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:crypto/crypto.dart";
import "package:path/path.dart" as path;

String attachmentSpillDirectoryPath({required String dataDirectory}) =>
    path.join(dataDirectory, "history", "attachments");

/// Raw file boundary for attachment bytes kept out of the database.
///
/// Files are content-addressed by the sha256 of their decoded bytes under a
/// per-session directory, so writing the same attachment twice is a no-op and
/// a purge is a single directory removal.
class AttachmentSpillStorage {
  AttachmentSpillStorage({required String directoryPath}) : _directoryPath = directoryPath;

  final String _directoryPath;

  /// Writes [bytes] if absent and returns their content address.
  Future<String> write({required String sessionId, required Uint8List bytes}) async {
    final digest = sha256.convert(bytes).toString();
    final file = File(_filePath(sessionId: sessionId, digest: digest));
    if (file.existsSync()) return digest;

    final directory = Directory(path.dirname(file.path));
    await directory.create(recursive: true);
    if (!Platform.isWindows) {
      await _setUnixMode(targetPath: directory.path, mode: "700");
    }
    if (Platform.isWindows) {
      await file.writeAsBytes(bytes, flush: true);
      return digest;
    }

    final temporary = File("${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp");
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await _setUnixMode(targetPath: temporary.path, mode: "600");
      await temporary.rename(file.path);
    } finally {
      if (temporary.existsSync()) {
        temporary.deleteSync();
      }
    }
    return digest;
  }

  /// The stored bytes, or null when the spill file is gone.
  Future<Uint8List?> read({required String sessionId, required String digest}) async {
    final file = File(_filePath(sessionId: sessionId, digest: digest));
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  /// Copies every spill file of [sessionId] into [destinationDirectoryPath].
  ///
  /// Idempotent: content-addressed names mean an already-copied file is left
  /// as it is.
  Future<void> copySession({
    required String sessionId,
    required String destinationDirectoryPath,
  }) async {
    final source = Directory(_sessionDirectoryPath(sessionId: sessionId));
    if (!source.existsSync()) return;

    final destination = Directory(destinationDirectoryPath);
    await destination.create(recursive: true);
    if (!Platform.isWindows) {
      await _setUnixMode(targetPath: destination.path, mode: "700");
    }
    await for (final entity in source.list(followLinks: false)) {
      if (entity is! File) continue;
      final target = File(path.join(destination.path, path.basename(entity.path)));
      if (target.existsSync()) continue;
      await entity.copy(target.path);
      if (!Platform.isWindows) {
        await _setUnixMode(targetPath: target.path, mode: "600");
      }
    }
  }

  Future<void> deleteSession({required String sessionId}) async {
    final directory = Directory(_sessionDirectoryPath(sessionId: sessionId));
    if (!directory.existsSync()) return;
    await directory.delete(recursive: true);
  }

  String _sessionDirectoryPath({required String sessionId}) => path.join(_directoryPath, _segment(id: sessionId));

  String _filePath({required String sessionId, required String digest}) =>
      path.join(_sessionDirectoryPath(sessionId: sessionId), digest);

  /// Session ids are bridge-generated (`ses_<hex>`), but they address a
  /// directory here, so encode rather than trust their shape.
  String _segment({required String id}) => base64Url.encode(utf8.encode(id));

  Future<void> _setUnixMode({required String targetPath, required String mode}) async {
    final result = await Process.run("chmod", [mode, targetPath]);
    if (result.exitCode != 0) {
      throw FileSystemException("Failed to set mode $mode", targetPath);
    }
  }
}
