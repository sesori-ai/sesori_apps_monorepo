import "package:path/path.dart" as p;

import "../models/antigravity_session_metadata.dart";
import "../storage/antigravity_session_metadata_storage.dart";

class AntigravitySessionMetadataRepository({required final AntigravitySessionMetadataStorage _storage}) {
  Future<({List<String> paths, bool truncated})> listPaths({required String geminiHome, required int maxEntries}) =>
      _storage.listPaths(geminiHome: geminiHome, maxEntries: maxEntries);

  Future<AntigravitySessionMetadata> read({required String path, required int maxBytes}) async {
    final dto = await _storage.read(path: path, maxBytes: maxBytes);
    return AntigravitySessionMetadata(
      sessionId: p.basenameWithoutExtension(path).toLowerCase(),
      // Preserve relativity for service validation; never resolve an invalid cwd
      // against the bridge process's own working directory.
      directory: p.normalize(dto.cwd),
    );
  }
}
