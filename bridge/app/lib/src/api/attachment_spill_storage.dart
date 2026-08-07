import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:crypto/crypto.dart";
import "package:path/path.dart" as path;

import "data_directory_hardening.dart";

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

  /// Creates the spill root with its intended permissions, so a fresh data
  /// directory has the same shape as one that has already stored attachments.
  void ensureDirectory() => createHardenedDirectory(directoryPath: _directoryPath);

  /// Writes [bytes] if absent and returns their content address.
  ///
  /// The write is atomic on every platform — bytes land in a temporary file
  /// that is renamed into place — so an interrupted write can never leave a
  /// partial file that a later `existsSync` check would trust.
  Future<String> write({required String sessionId, required Uint8List bytes}) async {
    final digest = sha256.convert(bytes).toString();
    final file = File(_filePath(sessionId: sessionId, digest: digest));
    if (file.existsSync()) return digest;

    final directory = Directory(path.dirname(file.path));
    await directory.create(recursive: true);
    await hardenPath(targetPath: directory.path, mode: ownerOnlyDirectoryMode);

    final temporary = File("${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp");
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await hardenPath(targetPath: temporary.path, mode: ownerOnlyFileMode);
      await temporary.rename(file.path);
    } on FileSystemException {
      // Windows refuses to rename onto an existing file. Content addressing
      // makes the winner of that race byte-identical, so an existing target is
      // success, not a failure.
      if (!file.existsSync()) rethrow;
    } finally {
      if (temporary.existsSync()) {
        temporary.deleteSync();
      }
    }
    return digest;
  }

  /// The stored bytes, or null when the spill file is gone.
  Future<Uint8List?> read({required String sessionId, required String digest}) async {
    if (!_isContentAddress(digest: digest)) {
      throw ArgumentError.value(digest, "digest", "not a sha256 content address");
    }
    final file = File(_filePath(sessionId: sessionId, digest: digest));
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  /// Guards the file boundary: only names this class generates may address a
  /// spill file, so a malformed reference can never escape the directory.
  static bool _isContentAddress({required String digest}) {
    return digest.length == 64 && RegExp(r"^[0-9a-f]{64}$").hasMatch(digest);
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
}
