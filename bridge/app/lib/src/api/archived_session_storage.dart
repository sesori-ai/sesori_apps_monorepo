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
/// Each write creates a **new, generation-stamped file** and only then removes
/// older generations for that session; nothing is ever replaced in place. The
/// newest generation is therefore always a complete file, so no interrupted
/// write can leave a session without a readable transcript and no recovery
/// step is needed.
///
/// This replaces an earlier replace-in-place scheme that needed a temp file, a
/// platform-specific rename fallback, and a displaced-copy slot that had to be
/// settled on every code path. Making the filename carry the generation
/// removes those states rather than coordinating them.
class ArchivedSessionStorage {
  ArchivedSessionStorage({required String directoryPath}) : _directoryPath = directoryPath;

  final String _directoryPath;

  /// Creates the archive root with its intended permissions, so a fresh data
  /// directory has the same shape (and mode) as one that has archived before.
  void ensureDirectory() => createHardenedDirectory(directoryPath: _directoryPath);

  Future<void> write({required String sessionId, required String contents}) async {
    await Directory(_directoryPath).create(recursive: true);
    await hardenPath(targetPath: _directoryPath, mode: ownerOnlyDirectoryMode);

    final existing = await _generationsFor(sessionId: sessionId);
    final generation = (existing.isEmpty ? 0 : existing.first.generation) + 1;
    final file = File(_filePath(sessionId: sessionId, generation: generation));

    // A partially written new generation is never the newest complete one,
    // because the reader falls back to the previous generation when the newest
    // fails to parse. Write it in place; there is no target to clobber.
    await file.writeAsString(contents, flush: true);
    await hardenPath(targetPath: file.path, mode: ownerOnlyFileMode);
    await _removeGenerations(files: existing);
  }

  /// The newest readable audit file, or null when this session has none.
  ///
  /// An unreadable newest generation is quarantined and the previous one is
  /// tried, so a crash mid-write costs at most the newer transcript rather
  /// than every one.
  Future<String?> read({required String sessionId}) async {
    for (final entry in await _generationsFor(sessionId: sessionId)) {
      try {
        return await entry.file.readAsString();
      } on FileSystemException catch (error, stackTrace) {
        // Includes malformed UTF-8, which would otherwise fail every archived
        // read for this session forever.
        Log.w("[archive] unreadable audit file ${entry.file.path}", error, stackTrace);
        await _quarantineFile(file: entry.file, sessionId: sessionId);
      }
    }
    return null;
  }

  Future<bool> exists({required String sessionId}) async =>
      (await _generationsFor(sessionId: sessionId)).isNotEmpty;

  /// Moves an unreadable file aside instead of deleting it: it may be the only
  /// remaining copy of that transcript, and a human may still salvage it.
  Future<void> quarantine({required String sessionId}) async {
    for (final entry in await _generationsFor(sessionId: sessionId)) {
      await _quarantineFile(file: entry.file, sessionId: sessionId);
    }
  }

  Future<void> delete({required String sessionId}) async {
    await _removeGenerations(files: await _generationsFor(sessionId: sessionId));
  }

  /// Every session id that has an audit file, for startup reconciliation.
  Future<Set<String>> listArchivedSessionIds() async {
    final ids = <String>{};
    await for (final entry in _entries()) {
      ids.add(entry.sessionId);
    }
    return ids;
  }

  Future<void> _quarantineFile({required File file, required String sessionId}) async {
    final quarantined = "${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}";
    try {
      await file.rename(quarantined);
      Log.w("[archive] quarantined an unreadable audit file for session $sessionId at $quarantined");
    } on FileSystemException catch (error, stackTrace) {
      Log.w("[archive] failed to quarantine the audit file for session $sessionId", error, stackTrace);
    }
  }

  Future<void> _removeGenerations({required List<_ArchiveGeneration> files}) async {
    for (final entry in files) {
      try {
        if (entry.file.existsSync()) await entry.file.delete();
      } on FileSystemException catch (error, stackTrace) {
        // An undeletable older generation is shadowed by the newer one, so a
        // failure here costs disk space rather than correctness.
        Log.w("[archive] failed to remove a superseded audit file ${entry.file.path}", error, stackTrace);
      }
    }
  }

  /// This session's generations, newest first.
  Future<List<_ArchiveGeneration>> _generationsFor({required String sessionId}) async {
    final matching = <_ArchiveGeneration>[];
    await for (final entry in _entries()) {
      if (entry.sessionId == sessionId) matching.add(entry);
    }
    matching.sort((left, right) => right.generation.compareTo(left.generation));
    return matching;
  }

  Stream<_ArchiveGeneration> _entries() async* {
    final directory = Directory(_directoryPath);
    if (!directory.existsSync()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final parsed = _parseName(name: path.basename(entity.path));
      if (parsed == null) continue;
      yield (sessionId: parsed.sessionId, generation: parsed.generation, file: entity);
    }
  }

  static const _extension = ".json";
  static const _separator = ".";

  String _filePath({required String sessionId, required int generation}) =>
      path.join(_directoryPath, "${_encodeSegment(id: sessionId)}$_separator$generation$_extension");

  /// Parses `<base64url session id>.<generation>.json`, ignoring anything else
  /// (quarantined files, leftovers from another tool).
  static ({String sessionId, int generation})? _parseName({required String name}) {
    if (!name.endsWith(_extension)) return null;
    final stem = name.substring(0, name.length - _extension.length);
    final separator = stem.lastIndexOf(_separator);
    if (separator <= 0) return null;
    final generation = int.tryParse(stem.substring(separator + 1));
    if (generation == null) return null;
    final sessionId = _decodeSegment(segment: stem.substring(0, separator));
    return sessionId == null ? null : (sessionId: sessionId, generation: generation);
  }

  /// Session ids are bridge-generated, but they name a file here, so encode
  /// rather than trust their shape.
  static String _encodeSegment({required String id}) => base64Url.encode(utf8.encode(id));

  static String? _decodeSegment({required String segment}) {
    try {
      return utf8.decode(base64Url.decode(segment));
    } on FormatException {
      // A file this class did not write.
      return null;
    }
  }
}

typedef _ArchiveGeneration = ({String sessionId, int generation, File file});
