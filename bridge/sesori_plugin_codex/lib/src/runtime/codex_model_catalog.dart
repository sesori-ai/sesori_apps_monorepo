import "dart:convert";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show CommandExecutor;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show HostJsonStore, Log;

/// Backend-namespaced static catalog generated from the exact Codex binary
/// selected for this bridge start.
const String codexModelCatalogFileName = "codex-model-catalog.json";

/// Generates a version-matched static model catalog and returns its absolute
/// path, or `null` when isolation cannot be prepared.
///
/// COMPATIBILITY 2026-07-23 (Codex 0.144.x/0.145.x): different Codex versions
/// share `models_cache.json` under CODEX_HOME even though its model schema is
/// not forward/backward compatible. Supplying `model_catalog_json` selects
/// Codex's static model manager, which neither reads nor renews that shared
/// cache. Remove this workaround once upstream versions the cache or guarantees
/// cross-version schema compatibility.
Future<String?> prepareCodexModelCatalog({
  required CommandExecutor commandExecutor,
  required HostJsonStore store,
  required String stateDirectory,
  required String executablePath,
  required Map<String, String> environment,
  required Duration timeout,
}) async {
  try {
    final result = await commandExecutor.run(
      executablePath,
      const ["debug", "models", "--bundled"],
      environment: environment,
      timeout: timeout,
    );
    if (result.exitCode != 0) {
      throw StateError(
        "Codex bundled model catalog command exited with code "
        "${result.exitCode}",
      );
    }
    final decoded = jsonDecode(result.stdout);
    if (decoded is! Map<String, dynamic> || decoded["models"] is! List || (decoded["models"] as List).isEmpty) {
      throw const FormatException(
        "Codex bundled model catalog did not contain a non-empty models list",
      );
    }
    // HostJsonStore makes replacement atomic, bridge startup is serialized
    // across instances, and Codex reads a static catalog only during startup.
    // Those three guarantees let later starts safely refresh one
    // backend-specific file instead of accumulating a file per Codex version.
    await store.write(
      name: codexModelCatalogFileName,
      contents: jsonEncode(decoded),
    );
    return p.join(stateDirectory, codexModelCatalogFileName);
  } on Object catch (error, stackTrace) {
    // COMPATIBILITY 2026-07-23 (Codex >=0.139): preserve startup for an
    // explicitly selected or patched binary that lacks `debug models
    // --bundled`. The normal cache path may still be noisy, so keep this
    // recovered fallback observable as one warning.
    Log.w(
      "[codex] failed to prepare an isolated model catalog; "
      "falling back to Codex's normal model cache",
      error,
      stackTrace,
    );
    return null;
  }
}
