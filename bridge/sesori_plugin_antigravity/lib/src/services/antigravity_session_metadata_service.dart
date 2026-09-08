import "package:acp_plugin/acp_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/antigravity_session_metadata_repository.dart";

/// Explicit import/cold recovery only. No cache, watcher, persistence, or scan on
/// ordinary reads; the caller registers one batch with existing ACP ownership.
class AntigravitySessionMetadataService({required final AntigravitySessionMetadataRepository _repository}) {
  static const maxEntries = 10000;
  static const maxFileBytes = 64 * 1024;
  static const maxDirectoryLength = 4096;
  static final _uuid = RegExp(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$");

  Future<AcpSessionDirectoryBatch> recover({required String geminiHome}) async {
    final directories = <String, String>{};
    try {
      final listing = await _repository.listPaths(geminiHome: geminiHome, maxEntries: maxEntries);
      if (listing.truncated) Log.w("[antigravity] metadata recovery in $geminiHome reached $maxEntries entries");
      for (final path in listing.paths) {
        try {
          final metadata = await _repository.read(path: path, maxBytes: maxFileBytes);
          if (!_uuid.hasMatch(metadata.sessionId) ||
              !p.isAbsolute(metadata.directory) ||
              metadata.directory.length > maxDirectoryLength ||
              metadata.directory.contains("\u0000")) {
            throw const FormatException("Metadata requires a UUID filename and bounded absolute cwd");
          }
          if (directories.containsKey(metadata.sessionId)) {
            Log.w("[antigravity] ignoring duplicate metadata for ${metadata.sessionId} at $path");
            continue;
          }
          directories[metadata.sessionId] = metadata.directory;
        } on Object catch (error, stackTrace) {
          Log.w("[antigravity] skipping metadata at $path", error, stackTrace);
        }
      }
    } on Object catch (error, stackTrace) {
      Log.w("[antigravity] metadata recovery failed in $geminiHome; retaining existing attribution", error, stackTrace);
    }
    return AcpSessionDirectoryBatch(directories: directories);
  }
}
