import "dart:io" as io;

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// Candidate paths of the `codex` CLI bundled by the Codex desktop app, for
/// users who installed the app without a standalone CLI on `PATH`.
///
/// - macOS: the app ships the CLI inside its bundle at
///   `<bundle>/Contents/Resources/codex`. The bundle is `ChatGPT.app` on newer
///   builds and `Codex.app` on older ones (both bundle id `com.openai.codex`),
///   under `/Applications` or `~/Applications` — the same locations the codex
///   CLI itself searches (`codex-rs/cli/src/desktop_app/mac.rs`).
/// - Windows: the MSIX app relocates its bundled CLI out of the launch-protected
///   `WindowsApps` directory to `%LOCALAPPDATA%\OpenAI\Codex\bin\codex.exe`,
///   with content-hash-named sibling subdirectories under that `bin` directory.
/// - Linux: no desktop app exists, so there are no candidates.
///
/// Returns launch candidates in preference order without probing them: callers
/// version-gate each candidate, and a missing path fails that probe harmlessly.
List<String> codexDesktopAppCliCandidates({
  required Map<String, String> environment,
  required PlatformOs os,
}) {
  switch (os) {
    case PlatformOs.macos:
      final home = resolveUserHomeDirectory(environment: environment);
      return [
        for (final root in [
          "/Applications",
          if (home != null) p.join(home, "Applications"),
        ])
          for (final bundle in const ["ChatGPT.app", "Codex.app"])
            p.join(root, bundle, "Contents", "Resources", "codex"),
      ];
    case PlatformOs.windows:
      final localAppData = environment["LOCALAPPDATA"];
      if (localAppData == null || localAppData.trim().isEmpty) return const [];
      final binDir = p.join(localAppData, "OpenAI", "Codex", "bin");
      return [
        p.join(binDir, "codex.exe"),
        for (final subdirectory in _subdirectoriesNewestFirst(directoryPath: binDir))
          p.join(subdirectory, "codex.exe"),
      ];
    case PlatformOs.linux:
      return const [];
  }
}

/// Subdirectory paths of [directoryPath], newest-modified first so the app's
/// most recently relocated CLI copy is probed before stale hash directories.
/// Each entry is stat-ed once; an entry removed mid-enumeration (`notFound`)
/// is skipped, and a listing failure degrades to no subdirectory candidates.
List<String> _subdirectoriesNewestFirst({required String directoryPath}) {
  try {
    final directory = io.Directory(directoryPath);
    if (!directory.existsSync()) return const [];
    final entries = [
      for (final subdirectory in directory.listSync().whereType<io.Directory>())
        (path: subdirectory.path, stat: subdirectory.statSync()),
    ]..sort((a, b) => b.stat.modified.compareTo(a.stat.modified));
    return [
      for (final entry in entries)
        if (entry.stat.type != io.FileSystemEntityType.notFound) entry.path,
    ];
  } on Object catch (error, stackTrace) {
    Log.w("[codex] could not list desktop-app CLI directory '$directoryPath'", error, stackTrace);
    return const [];
  }
}
