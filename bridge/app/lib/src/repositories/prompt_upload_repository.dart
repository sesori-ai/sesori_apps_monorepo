import "dart:convert" show utf8;
import "dart:io" show Directory, PathNotFoundException;

import "package:clock/clock.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../api/filesystem_api.dart";

/// Owns the files sent with prompts, kept on disk as
/// `<root>/<sessionId>/<YYYY-MM-DD>-<random>/<name>`.
///
/// One folder per session, so a session's files go with one delete, and one
/// folder per file, so names never collide. Only the current user can open
/// the folders and files.
class PromptUploadRepository({
  required final FilesystemApi _filesystemApi,
  required final String _uploadsRoot,
}) {
  static const _maxNameLength = 120;

  /// Below the 255-byte name limit of common Linux filesystems such as ext4.
  static const _maxNameBytes = 240;
  static const _fallbackName = "attachment";

  /// Characters that would break the noted path as inline code, as one
  /// unquoted shell word (splitting, expansion, globbing), or as a single path
  /// segment.
  static final _unsafeNameCharacters = RegExp(r"""[\s\x00-\x1F\x7F"'`*?<>|:/\\$;&()\[\]{}!]""");
  static final _pathSeparator = RegExp(r"[/\\]");
  static final _datedFolderName = RegExp(r"^\d{4}-\d{2}-\d{2}-");

  /// Saves [bytes] under a sanitized [filename] in a new folder inside the
  /// session's folder, and returns the file's path.
  ///
  /// A failed write removes the new folder and rethrows. Throws [StateError]
  /// when [sessionId] is not a single path segment.
  Future<String> save({required String sessionId, required List<int> bytes, required String filename}) async {
    final sessionFolder = _sessionFolder(sessionId: sessionId);
    await _filesystemApi.createOwnerOnlyDirectory(path: _uploadsRoot);
    await _filesystemApi.createOwnerOnlyDirectory(path: sessionFolder);
    final fileFolder = await _filesystemApi.createOwnerOnlyTemporaryDirectory(
      parent: sessionFolder,
      prefix: "${_formatDate(date: clock.now())}-",
    );
    try {
      final filePath = p.join(fileFolder, _sanitizeName(filename: filename));
      await _filesystemApi.writeOwnerOnlyFile(path: filePath, bytes: bytes);
      return filePath;
    } on Object {
      await _deleteFolderOfFailedSave(path: fileFolder);
      rethrow;
    }
  }

  /// Deletes the folders of [sessionIds] with every file in them. A session
  /// that has no folder is skipped.
  ///
  /// Throws [StateError] when an id is not a single path segment.
  Future<void> deleteSessions({required List<String> sessionIds}) async {
    await Future.wait([for (final sessionId in sessionIds) _deleteSessionFolder(sessionId: sessionId)]);
  }

  /// Deletes, in every session folder, each file folder dated before the day
  /// of [cutoff], so every file it removes was saved before [cutoff].
  ///
  /// Folders whose name holds no date are kept. Session folders are kept even
  /// when empty: removing one could race a save into the same session. A
  /// folder that something else removed meanwhile is skipped, and so is a
  /// root that doesn't exist yet because no file was ever saved.
  Future<void> deleteFileFoldersDatedBefore({required DateTime cutoff}) async {
    final cutoffDay = DateTime(cutoff.year, cutoff.month, cutoff.day);
    final List<Directory> sessionFolders;
    try {
      sessionFolders = await _filesystemApi.listDirectoriesAsync(path: _uploadsRoot);
    } on PathNotFoundException {
      return;
    }
    for (final sessionFolder in sessionFolders) {
      await _deleteFileFoldersDatedBefore(sessionFolder: sessionFolder.path, cutoffDay: cutoffDay);
    }
  }

  Future<void> _deleteFileFoldersDatedBefore({required String sessionFolder, required DateTime cutoffDay}) async {
    final List<Directory> fileFolders;
    try {
      fileFolders = await _filesystemApi.listDirectoriesAsync(path: sessionFolder);
    } on PathNotFoundException {
      Log.d("Skipped the upload folder $sessionFolder; its session was deleted meanwhile");
      return;
    }
    for (final fileFolder in fileFolders) {
      final date = _parseFolderDate(folderName: p.basename(fileFolder.path));
      if (date == null || !date.isBefore(cutoffDay)) continue;
      try {
        await _filesystemApi.deleteDirectoryRecursivelyAsync(path: fileFolder.path);
      } on PathNotFoundException {
        Log.d("Skipped the upload folder ${fileFolder.path}; it was already removed");
      }
    }
  }

  Future<void> _deleteSessionFolder({required String sessionId}) async {
    final sessionFolder = _sessionFolder(sessionId: sessionId);
    try {
      await _filesystemApi.deleteDirectoryRecursivelyAsync(path: sessionFolder);
    } on PathNotFoundException {
      // The usual case: most sessions never had a file sent with a prompt.
      return;
    }
  }

  /// Session ids are the bridge's own `ses_` ids, never client text; this
  /// still keeps a bad one from naming a folder outside its own.
  String _sessionFolder({required String sessionId}) {
    if (sessionId.isEmpty || sessionId == "." || sessionId == ".." || sessionId.contains(_pathSeparator)) {
      throw StateError("Session id $sessionId is not a single path segment");
    }
    return p.join(_uploadsRoot, sessionId);
  }

  /// Best-effort: the save already fails with its own error, so a folder left
  /// here only waits for the age sweep.
  Future<void> _deleteFolderOfFailedSave({required String path}) async {
    try {
      await _filesystemApi.deleteDirectoryRecursivelyAsync(path: path);
    } on Object catch (error, stackTrace) {
      Log.w("Could not remove the folder $path of a prompt upload that failed to save", error, stackTrace);
    }
  }

  /// Keeps only the last `/` segment and replaces [_unsafeNameCharacters],
  /// including `\`, with `_`. Uses [_fallbackName] for `.`, `..` and an empty
  /// name, and shortens the stem on whole characters so the name has at most
  /// [_maxNameLength] characters and [_maxNameBytes] UTF-8 bytes.
  static String _sanitizeName({required String filename}) {
    final name = p.posix.basename(filename).replaceAll(_unsafeNameCharacters, "_");
    if (name.isEmpty || name == "." || name == "..") return _fallbackName;
    if (_fitsNameLimits(name: name)) return name;
    final extension = p.posix.extension(name);
    // An extension that leaves no room for the stem is cut with the name.
    final keptExtension = _fitsNameLimits(name: extension) && extension.runes.length < _maxNameLength ? extension : "";
    final stem = name.substring(0, name.length - keptExtension.length);
    final characterBudget = _maxNameLength - keptExtension.runes.length;
    final byteBudget = _maxNameBytes - utf8.encode(keptExtension).length;
    final keptStem = StringBuffer();
    var characters = 0;
    var bytes = 0;
    for (final character in stem.runes) {
      final characterBytes = utf8.encode(String.fromCharCode(character)).length;
      if (characters == characterBudget || bytes + characterBytes > byteBudget) break;
      keptStem.writeCharCode(character);
      characters++;
      bytes += characterBytes;
    }
    return "$keptStem$keptExtension";
  }

  static bool _fitsNameLimits({required String name}) {
    return name.runes.length <= _maxNameLength && utf8.encode(name).length <= _maxNameBytes;
  }

  static DateTime? _parseFolderDate({required String folderName}) {
    if (!_datedFolderName.hasMatch(folderName)) return null;
    return DateTime.tryParse(folderName.substring(0, 10));
  }

  static String _formatDate({required DateTime date}) {
    final year = date.year.toString().padLeft(4, "0");
    final month = date.month.toString().padLeft(2, "0");
    final day = date.day.toString().padLeft(2, "0");
    return "$year-$month-$day";
  }
}
