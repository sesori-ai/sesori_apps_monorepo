import "dart:convert";
import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "data_directory_hardening.dart";

String archiveDirectoryPath({required String dataDirectory}) => path.join(dataDirectory, "archive");

String archivedAttachmentDirectoryPath({required String dataDirectory}) =>
    path.join(dataDirectory, "archive", "attachments");

/// Raw file boundary for archived session audit files.
///
/// Files are written atomically (temp + rename) so a crash mid-write can never
/// leave a half-written audit record where a complete one is expected.
class ArchivedSessionStorage {
  ArchivedSessionStorage({required String directoryPath}) : _directoryPath = directoryPath;

  final String _directoryPath;

  /// Creates the archive root with its intended permissions, so a fresh data
  /// directory has the same shape (and mode) as one that has archived before.
  void ensureDirectory() => createHardenedDirectory(directoryPath: _directoryPath);

  Future<void> write({required String sessionId, required String contents}) async {
    final file = File(_filePath(sessionId: sessionId));
    await Directory(path.dirname(file.path)).create(recursive: true);
    await hardenPath(targetPath: path.dirname(file.path), mode: ownerOnlyDirectoryMode);

    final temporary = File("${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp");
    try {
      await temporary.writeAsString(contents, flush: true);
      await hardenPath(targetPath: temporary.path, mode: ownerOnlyFileMode);
      try {
        await temporary.rename(file.path);
      } on FileSystemException {
        // Windows refuses to rename onto an existing file. Re-archiving must
        // still replace the previous audit file, so remove it and retry.
        if (!file.existsSync()) rethrow;
        await file.delete();
        await temporary.rename(file.path);
      }
    } finally {
      if (temporary.existsSync()) temporary.deleteSync();
    }
  }

  /// The stored audit file, or null when this session was never archived.
  Future<String?> read({required String sessionId}) async {
    final file = File(_filePath(sessionId: sessionId));
    if (!file.existsSync()) return null;
    try {
      return await file.readAsString();
    } on FileSystemException catch (error, stackTrace) {
      // Includes malformed UTF-8, which would otherwise fail every archived
      // read for this session forever.
      Log.w("[archive] unreadable audit file bytes for session $sessionId", error, stackTrace);
      await quarantine(sessionId: sessionId);
      return null;
    }
  }

  Future<bool> exists({required String sessionId}) async =>
      File(_filePath(sessionId: sessionId)).existsSync();

  /// Moves an unreadable file aside instead of deleting it: it is the only
  /// remaining copy of that transcript, and a human may still salvage it.
  Future<void> quarantine({required String sessionId}) async {
    final file = File(_filePath(sessionId: sessionId));
    if (!file.existsSync()) return;
    final quarantined = "${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}";
    try {
      await file.rename(quarantined);
      Log.w("[archive] quarantined an unreadable audit file for session $sessionId at $quarantined");
    } on FileSystemException catch (error, stackTrace) {
      Log.w("[archive] failed to quarantine the audit file for session $sessionId", error, stackTrace);
    }
  }

  Future<void> delete({required String sessionId}) async {
    final file = File(_filePath(sessionId: sessionId));
    if (file.existsSync()) await file.delete();
  }

  /// Every session id that has an audit file, for startup reconciliation.
  Future<Set<String>> listArchivedSessionIds() async {
    final directory = Directory(_directoryPath);
    if (!directory.existsSync()) return const {};
    final ids = <String>{};
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = path.basename(entity.path);
      if (!name.endsWith(_extension)) continue;
      ids.add(_decodeSegment(segment: name.substring(0, name.length - _extension.length)));
    }
    return ids;
  }

  static const _extension = ".json";

  String _filePath({required String sessionId}) =>
      path.join(_directoryPath, "${_encodeSegment(id: sessionId)}$_extension");

  /// Session ids are bridge-generated, but they name a file here, so encode
  /// rather than trust their shape.
  static String _encodeSegment({required String id}) => base64Url.encode(utf8.encode(id));

  static String _decodeSegment({required String segment}) {
    try {
      return utf8.decode(base64Url.decode(segment));
    } on FormatException {
      // A file this class did not write; reconcile simply will not match it.
      return segment;
    }
  }
}
