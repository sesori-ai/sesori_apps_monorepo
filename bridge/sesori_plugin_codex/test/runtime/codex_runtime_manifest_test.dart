import "package:codex_plugin/src/runtime/codex_plugin_descriptor.dart";
import "package:codex_plugin/src/runtime/codex_runtime_manifest.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginStateStorage;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = CodexRuntimeManifest();

  group("CodexRuntimeManifest", () {
    test("descriptor preserves the legacy shared runtime directory", () {
      expect(const CodexPluginDescriptor().stateStorage, PluginStateStorage.legacySharedRuntime);
    });

    test("pinned versions", () {
      expect(manifest.bundledVersion.toString(), "0.144.5");
      expect(manifest.minPathVersion.toString(), "0.139.0");
      expect(manifest.runtimeId, const CodexPluginDescriptor().id);
      expect(manifest.pathExecutableName, "codex");
    });

    test("pins a sha256 asset for every platform target", () {
      for (final os in PlatformOs.values) {
        for (final arch in PlatformArch.values) {
          final asset = manifest.assetFor(
            target: PlatformTarget(os: os, arch: arch),
          );
          expect(asset, isNotNull, reason: "missing asset for $os/$arch");
          expect(asset!.sha256, matches(RegExp(r"^[0-9a-f]{64}$")), reason: "$os/$arch sha256");
          expect(asset.assetName, isNotEmpty);
        }
      }
    });

    test("darwin/linux ship .tar.gz, windows ships .exe.zip", () {
      RuntimeAsset asset(PlatformOs os, PlatformArch arch) => manifest.assetFor(
        target: PlatformTarget(os: os, arch: arch),
      )!;

      expect(asset(PlatformOs.macos, PlatformArch.arm64).format, ArchiveFormat.tarGz);
      expect(asset(PlatformOs.macos, PlatformArch.arm64).assetName, endsWith(".tar.gz"));
      expect(asset(PlatformOs.linux, PlatformArch.x64).format, ArchiveFormat.tarGz);
      expect(asset(PlatformOs.linux, PlatformArch.x64).assetName, endsWith(".tar.gz"));

      for (final arch in PlatformArch.values) {
        final windows = asset(PlatformOs.windows, arch);
        expect(windows.format, ArchiveFormat.zip, reason: "windows/$arch format");
        expect(windows.assetName, endsWith(".exe.zip"), reason: "windows/$arch asset");
      }
    });

    test("archive member is the target-triple name (asset name minus extension)", () {
      expect(
        manifest
            .assetFor(
              target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
            )!
            .archiveBinaryName,
        "codex-aarch64-apple-darwin",
      );
      expect(
        manifest
            .assetFor(
              target: const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64),
            )!
            .archiveBinaryName,
        "codex-x86_64-unknown-linux-musl",
      );
      expect(
        manifest
            .assetFor(
              target: const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64),
            )!
            .archiveBinaryName,
        "codex-x86_64-pc-windows-msvc.exe",
      );
    });

    test("download URL embeds the rust-v bundled tag and asset name", () {
      final asset = manifest.assetFor(
        target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
      )!;
      expect(
        manifest.downloadUrlFor(asset: asset),
        equals("https://github.com/openai/codex/releases/download/rust-v0.144.5/codex-aarch64-apple-darwin.tar.gz"),
      );
    });

    test("bundled version is at least the minimum PATH version", () {
      expect(manifest.bundledVersion.compareTo(manifest.minPathVersion), greaterThanOrEqualTo(0));
    });
  });
}
