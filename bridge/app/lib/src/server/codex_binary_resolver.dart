import "dart:async";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:http/http.dart" as http;
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// The codex-cli version this bridge release is tested against.
///
/// Bumping codex is a deliberate release-engineering act: change this string,
/// fill in the matching SHA-256 hashes in [codexSha256Manifest], regenerate
/// the codex protocol bindings from `codex app-server generate-json-schema`,
/// then re-run integration tests.
const String pinnedCodexVersion = "0.121.0";

/// SHA-256 of the platform-specific codex release tarball, keyed by
/// `${platform}-${arch}` (matching [_currentPlatformKey]).
///
/// **Empty values disable auto-download for that platform.** When the hash
/// is empty, [CodexBinaryResolver] falls back to PATH lookup rather than
/// downloading an unverified binary. Release engineers fill these in from
/// the published checksums on the GitHub release page before tagging a
/// bridge release.
const Map<String, String> codexSha256Manifest = {
  "darwin-arm64": "",
  "darwin-x64": "",
  "linux-x64": "",
  "linux-arm64": "",
  "windows-x64": "",
};

/// Asset filename inside the GitHub release for a given platform key.
const Map<String, String> _codexAssetFor = {
  "darwin-arm64": "codex-aarch64-apple-darwin.tar.gz",
  "darwin-x64": "codex-x86_64-apple-darwin.tar.gz",
  "linux-x64": "codex-x86_64-unknown-linux-musl.tar.gz",
  "linux-arm64": "codex-aarch64-unknown-linux-musl.tar.gz",
  "windows-x64": "codex-x86_64-pc-windows-msvc.zip",
};

String _githubReleaseUrl(String asset) =>
    "https://github.com/openai/codex/releases/download/rust-v$pinnedCodexVersion/$asset";

/// Resolves the codex binary path used to spawn `codex app-server`.
///
/// Resolution priority (highest to lowest):
///   1. `--codex-bin` if it points to an existing executable file.
///   2. Cached managed binary at
///      `~/.local/share/sesori/codex/<pinned-version>/codex`.
///   3. Auto-download from GitHub Releases when [codexSha256Manifest] has
///      a non-empty hash for the current platform.
///   4. The raw `--codex-bin` string — handed to `Process.start` which
///      will resolve it on `PATH`.
class CodexBinaryResolver {
  final String _codexBinFlag;
  final Map<String, String> _environment;
  final http.Client _httpClient;
  final Future<void> Function(String tarballPath, String destDir) _extractor;

  CodexBinaryResolver({
    required String codexBinFlag,
    Map<String, String>? environment,
    http.Client? httpClient,
    Future<void> Function(String tarballPath, String destDir)? extractor,
  }) : _codexBinFlag = codexBinFlag,
       _environment = environment ?? Platform.environment,
       _httpClient = httpClient ?? http.Client(),
       _extractor = extractor ?? _defaultExtract;

  /// Returns the absolute path or command name to spawn for `codex app-server`.
  ///
  /// Never throws — failures degrade to PATH lookup. Logs the path it chose
  /// at info level so operators can confirm which codex they're driving.
  Future<String> resolve() async {
    final explicit = await _resolveExplicit();
    if (explicit != null) {
      Log.i("codex: using --codex-bin override at $explicit");
      return explicit;
    }

    final cached = _cachedBinaryPath();
    if (cached != null && File(cached).existsSync()) {
      Log.i("codex: using cached binary at $cached");
      return cached;
    }

    final downloaded = await _tryDownload();
    if (downloaded != null) {
      Log.i("codex: downloaded binary to $downloaded");
      return downloaded;
    }

    Log.i("codex: falling back to PATH lookup of '$_codexBinFlag'");
    return _codexBinFlag;
  }

  Future<String?> _resolveExplicit() async {
    // Default flag value is the bare 'codex' string — treat that as
    // "no override, do the normal resolution dance".
    if (_codexBinFlag == "codex" || _codexBinFlag.isEmpty) return null;
    final file = File(_codexBinFlag);
    if (!file.existsSync()) return null;
    return file.absolute.path;
  }

  String? _cachedBinaryPath() {
    final home = _environment["HOME"] ?? _environment["USERPROFILE"];
    if (home == null || home.isEmpty) return null;
    final dataHome = _environment["XDG_DATA_HOME"] ?? p.join(home, ".local", "share");
    final binName = Platform.isWindows ? "codex.exe" : "codex";
    return p.join(dataHome, "sesori", "codex", pinnedCodexVersion, binName);
  }

  Future<String?> _tryDownload() async {
    final key = _currentPlatformKey();
    if (key == null) return null;
    final expectedSha = codexSha256Manifest[key];
    final asset = _codexAssetFor[key];
    if (expectedSha == null || expectedSha.isEmpty || asset == null) {
      Log.d("codex: no checksum on file for platform '$key', skipping download");
      return null;
    }

    final destPath = _cachedBinaryPath();
    if (destPath == null) return null;
    final destDir = p.dirname(destPath);
    final url = _githubReleaseUrl(asset);

    try {
      final dir = Directory(destDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final tarballPath = p.join(destDir, asset);
      Log.i("codex: downloading $url");
      final response = await _httpClient.get(Uri.parse(url));
      if (response.statusCode != 200) {
        Log.w(
          "codex: download failed (HTTP ${response.statusCode}), "
          "falling back to PATH",
        );
        return null;
      }
      File(tarballPath).writeAsBytesSync(response.bodyBytes);

      final actualSha = sha256.convert(response.bodyBytes).toString();
      if (actualSha != expectedSha) {
        Log.e(
          "codex: SHA-256 mismatch for $asset "
          "(expected $expectedSha, got $actualSha) — refusing to use",
        );
        File(tarballPath).deleteSync();
        return null;
      }

      await _extractor(tarballPath, destDir);
      try {
        File(tarballPath).deleteSync();
      } catch (_) {
        // Tarball cleanup is best-effort.
      }
      if (!File(destPath).existsSync()) {
        Log.w("codex: archive extracted but '$destPath' not found");
        return null;
      }
      if (!Platform.isWindows) {
        await Process.run("chmod", ["+x", destPath]);
      }
      return destPath;
    } catch (error) {
      Log.w("codex: download path failed ($error), falling back to PATH");
      return null;
    }
  }

  String? _currentPlatformKey() {
    if (Platform.isMacOS) {
      return _isArm64() ? "darwin-arm64" : "darwin-x64";
    }
    if (Platform.isLinux) {
      return _isArm64() ? "linux-arm64" : "linux-x64";
    }
    if (Platform.isWindows) {
      return "windows-x64";
    }
    return null;
  }

  bool _isArm64() {
    final raw = (_environment["HOSTTYPE"] ?? "").toLowerCase();
    if (raw.contains("arm") || raw.contains("aarch")) return true;
    // Fallback: rely on uname when available.
    try {
      final result = Process.runSync("uname", const ["-m"]);
      final out = (result.stdout as String).trim().toLowerCase();
      return out.contains("arm") || out.contains("aarch");
    } catch (_) {
      return false;
    }
  }
}

Future<void> _defaultExtract(String tarballPath, String destDir) async {
  if (tarballPath.endsWith(".zip")) {
    final result = await Process.run(
      "unzip",
      ["-o", tarballPath, "-d", destDir],
    );
    if (result.exitCode != 0) {
      throw Exception("unzip failed: ${result.stderr}");
    }
    return;
  }
  final result = await Process.run(
    "tar",
    ["-xzf", tarballPath, "-C", destDir],
  );
  if (result.exitCode != 0) {
    throw Exception("tar failed: ${result.stderr}");
  }
}
