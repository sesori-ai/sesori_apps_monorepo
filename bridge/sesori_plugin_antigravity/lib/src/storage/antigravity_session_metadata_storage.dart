import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_shared/sesori_shared.dart";

import "models/antigravity_session_metadata_dto.dart";

/// Read-only boundary for this prepared profile's conversation metadata. Never
/// traverses subdirectories, follows listed links, or opens SQLite/brain files.
class const AntigravitySessionMetadataStorage() {
  Future<({List<String> paths, bool truncated})> listPaths({
    required String geminiHome,
    required int maxEntries,
  }) async {
    final directory = Directory(p.join(geminiHome, "antigravity-acp", "conversations"));
    if (!directory.existsSync()) return (paths: const <String>[], truncated: false);
    final paths = <String>[];
    var count = 0;
    var truncated = false;
    await for (final entry in directory.list(followLinks: false)) {
      if (++count > maxEntries) {
        truncated = true;
        break;
      }
      if (entry is File && p.extension(entry.path) == ".meta") paths.add(entry.path);
    }
    paths.sort();
    return (paths: List<String>.unmodifiable(paths), truncated: truncated);
  }

  Future<AntigravitySessionMetadataDto> read({required String path, required int maxBytes}) async {
    final file = await File(path).open();
    final List<int> bytes;
    try {
      bytes = await file.read(maxBytes + 1);
    } finally {
      await file.close();
    }
    if (bytes.length > maxBytes) throw const FormatException("Antigravity metadata exceeds the byte limit");
    try {
      return AntigravitySessionMetadataDto.fromJson(jsonDecodeMap(utf8.decode(bytes)));
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(_MetadataDecodeException(cause: error), stackTrace);
    }
  }
}

/// Keep the original diagnostic evidence without printing ignored JSON values.
// ignore: no_slop_linter/prefer_specific_type, retain original decoder evidence without rendering payload values
class const _MetadataDecodeException({required final Object cause}) implements Exception {
  @override
  String toString() => switch (cause) {
    FormatException(:final offset) => "Invalid Antigravity metadata JSON at offset $offset",
    _ => "Invalid Antigravity metadata cwd (${cause.runtimeType.toString()})",
  };
}
