import "dart:async";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:http/http.dart" as http;
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// The codex-cli version this bridge release is tested against.
///
/// Bumping codex is a deliberate release-engineering act: change this string,
/// refresh the matching SHA-256 hashes in [codexSha256Manifest] from the GitHub
/// release's published asset digests, confirm the [codexAssetFor] filenames
/// still match the release, and re-run the integration tests.
const String pinnedCodexVersion = "0.132.0";

/// SHA-256 of the platform-specific codex release archive, keyed by
/// `${platform}-${arch}` (matching [currentCodexPlatformKey]).
///
/// **Empty values disable auto-download for that platform.** When the hash is
/// empty, [CodexBinaryResolver] falls back to PATH lookup rather than
/// downloading an unverified binary. The hashes below are the published asset
/// digests for codex `rust-v0.132.0` (the GitHub release asset `digest` field,
/// verified against the downloaded archive).
const Map<String, String> codexSha256Manifest = {
  "darwin-arm64": "73258e01c122941c21bb8afbb81daff2ffdd8d3e803754fd411340c24257fdce",
  "darwin-x64": "58acad9af4f3b6dbabf6a1255baeac2384310b208d8b14a8899772cc72f99ea1",
  "linux-x64": "8b64432ee4ef5b1d7d197aad4535a276bc85223f4e4163769c0e1015cda883b2",
  "linux-arm64": "ae80a8ffb41abfca4eba9746cd3ba90403d57b02bdbcd68455f560890ad9f440",
  "windows-x64": "6bcd3b4051b4d05b3e07d039234d3b86b343d0b3322e36367e6ca39c3e106024",
};

/// Asset filename inside the GitHub release for a given platform key.
///
/// codex's release archives each contain a single binary named with the full
/// target triple (e.g. `codex-aarch64-apple-darwin`), not a bare `codex`; the
/// Windows asset is the `.exe.zip` whose member is
/// `codex-x86_64-pc-windows-msvc.exe`. [codexBinaryNameInArchive] derives that
/// member name, and the resolver normalizes it to the canonical cached name.
const Map<String, String> codexAssetFor = {
  "darwin-arm64": "codex-aarch64-apple-darwin.tar.gz",
  "darwin-x64": "codex-x86_64-apple-darwin.tar.gz",
  "linux-x64": "codex-x86_64-unknown-linux-musl.tar.gz",
  "linux-arm64": "codex-aarch64-unknown-linux-musl.tar.gz",
  "windows-x64": "codex-x86_64-pc-windows-msvc.exe.zip",
};

String _githubReleaseUrl(String asset) =>
    "https://github.com/openai/codex/releases/download/rust-v$pinnedCodexVersion/$asset";

/// The binary's name inside a release [asset] archive: the asset filename with
/// its archive extension (`.tar.gz` / `.zip`) stripped. For codex's archives
/// this is the target-triple-named binary, e.g.
/// `codex-aarch64-apple-darwin.tar.gz` → `codex-aarch64-apple-darwin` and
/// `codex-x86_64-pc-windows-msvc.exe.zip` → `codex-x86_64-pc-windows-msvc.exe`.
String codexBinaryNameInArchive(String asset) {
  for (final ext in const [".tar.gz", ".zip"]) {
    if (asset.endsWith(ext)) {
      return asset.substring(0, asset.length - ext.length);
    }
  }
  return asset;
}

/// The `${platform}-${arch}` manifest key for the host, or null on an
/// unsupported platform. Arch is read from `HOSTTYPE` (then `uname -m`).
String? currentCodexPlatformKey({required Map<String, String> environment}) {
  if (Platform.isMacOS) {
    return _codexIsArm64(environment) ? "darwin-arm64" : "darwin-x64";
  }
  if (Platform.isLinux) {
    return _codexIsArm64(environment) ? "linux-arm64" : "linux-x64";
  }
  if (Platform.isWindows) {
    return "windows-x64";
  }
  return null;
}

bool _codexIsArm64(Map<String, String> environment) {
  final raw = (environment["HOSTTYPE"] ?? "").toLowerCase();
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
  final Map<String, String> _manifest;
  final http.Client _httpClient;
  final Future<void> Function(String archivePath, String destDir) _extractor;

  CodexBinaryResolver({
    required String codexBinFlag,
    Map<String, String>? environment,
    Map<String, String>? sha256Manifest,
    http.Client? httpClient,
    Future<void> Function(String archivePath, String destDir)? extractor,
  }) : _codexBinFlag = codexBinFlag,
       _environment = environment ?? Platform.environment,
       _manifest = sha256Manifest ?? codexSha256Manifest,
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
    final key = currentCodexPlatformKey(environment: _environment);
    if (key == null) return null;
    final expectedSha = _manifest[key];
    final asset = codexAssetFor[key];
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

      final archivePath = p.join(destDir, asset);
      Log.i("codex: downloading $url");
      final response = await _httpClient.get(Uri.parse(url));
      if (response.statusCode != 200) {
        Log.w(
          "codex: download failed (HTTP ${response.statusCode}), "
          "falling back to PATH",
        );
        return null;
      }
      File(archivePath).writeAsBytesSync(response.bodyBytes);

      final actualSha = sha256.convert(response.bodyBytes).toString();
      if (actualSha != expectedSha) {
        Log.e(
          "codex: SHA-256 mismatch for $asset "
          "(expected $expectedSha, got $actualSha) — refusing to use",
        );
        File(archivePath).deleteSync();
        return null;
      }

      await _extractor(archivePath, destDir);
      try {
        File(archivePath).deleteSync();
      } catch (_) {
        // Archive cleanup is best-effort.
      }

      // The release archives unpack to a target-triple-named binary (e.g.
      // `codex-aarch64-apple-darwin`), not a bare `codex`. Normalize it to the
      // canonical cached path so the resolver and the spawn agree on one name.
      _normalizeExtractedBinary(asset: asset, destDir: destDir, destPath: destPath);

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

  /// Renames the extracted target-triple-named binary to the canonical cached
  /// [destPath] (`codex` / `codex.exe`). A no-op when the archive already
  /// produced the canonical name.
  void _normalizeExtractedBinary({
    required String asset,
    required String destDir,
    required String destPath,
  }) {
    if (File(destPath).existsSync()) return;
    final extracted = File(p.join(destDir, codexBinaryNameInArchive(asset)));
    if (extracted.existsSync()) {
      extracted.renameSync(destPath);
    }
  }
}

Future<void> _defaultExtract(String archivePath, String destDir) async {
  if (archivePath.endsWith(".zip")) {
    // Windows lacks `unzip` but ships bsdtar (`tar`), which extracts zips;
    // elsewhere prefer `unzip`.
    final result = Platform.isWindows
        ? await Process.run("tar", ["-xf", archivePath, "-C", destDir])
        : await Process.run("unzip", ["-o", archivePath, "-d", destDir]);
    if (result.exitCode != 0) {
      throw Exception("zip extraction failed: ${result.stderr}");
    }
    return;
  }
  final result = await Process.run(
    "tar",
    ["-xzf", archivePath, "-C", destDir],
  );
  if (result.exitCode != 0) {
    throw Exception("tar failed: ${result.stderr}");
  }
}
