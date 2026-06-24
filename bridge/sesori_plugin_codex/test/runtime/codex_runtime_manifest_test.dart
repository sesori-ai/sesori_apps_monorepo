import "package:codex_plugin/src/runtime/codex_runtime_manifest.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = CodexRuntimeManifest();

  // codex publishes builds for every target except windows-arm64.
  const supported = [
    PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
    PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64),
    PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.arm64),
    PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64),
    PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64),
  ];

  group("CodexRuntimeManifest", () {
    test("pinned versions", () {
      expect(manifest.bundledVersion.toString(), "0.142.0");
      expect(manifest.minPathVersion.toString(), "0.139.0");
      expect(manifest.runtimeId, "codex");
      expect(manifest.pathExecutableName, "codex");
    });

    test("pins a sha256 asset for every supported platform target", () {
      for (final target in supported) {
        final asset = manifest.assetFor(target: target);
        expect(asset, isNotNull, reason: "missing asset for ${target.key}");
        expect(asset!.sha256, matches(RegExp(r"^[0-9a-f]{64}$")), reason: "${target.key} sha256");
        expect(asset.assetName, isNotEmpty);
      }
    });

    test("windows-arm64 is unsupported (codex publishes no build)", () {
      expect(
        manifest.assetFor(target: const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.arm64)),
        isNull,
      );
    });

    test("darwin/linux ship .tar.gz, windows ships .exe.zip", () {
      RuntimeAsset asset(PlatformTarget target) => manifest.assetFor(target: target)!;

      expect(asset(supported[0]).format, ArchiveFormat.tarGz);
      expect(asset(supported[0]).assetName, endsWith(".tar.gz"));
      expect(asset(supported[3]).format, ArchiveFormat.tarGz);
      expect(asset(supported[3]).assetName, endsWith(".tar.gz"));

      final windows = asset(const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64));
      expect(windows.format, ArchiveFormat.zip);
      expect(windows.assetName, endsWith(".exe.zip"));
    });

    test("archive member is the target-triple name (asset name minus extension)", () {
      expect(
        manifest.assetFor(target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64))!.archiveBinaryName,
        "codex-aarch64-apple-darwin",
      );
      expect(
        manifest.assetFor(target: const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64))!.archiveBinaryName,
        "codex-x86_64-unknown-linux-musl",
      );
      expect(
        manifest.assetFor(target: const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64))!.archiveBinaryName,
        "codex-x86_64-pc-windows-msvc.exe",
      );
    });

    test("download URL embeds the rust-v bundled tag and asset name", () {
      final asset = manifest.assetFor(
        target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
      )!;
      expect(
        manifest.downloadUrlFor(asset: asset),
        equals("https://github.com/openai/codex/releases/download/rust-v0.142.0/codex-aarch64-apple-darwin.tar.gz"),
      );
    });

    test("bundled version is at least the minimum PATH version", () {
      expect(manifest.bundledVersion.compareTo(manifest.minPathVersion), greaterThanOrEqualTo(0));
    });
  });
}
