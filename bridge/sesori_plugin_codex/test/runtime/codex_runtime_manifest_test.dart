import "dart:io" show Platform;

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
      expect(CodexRuntimeManifest.targetVersion, "0.164.0");
      expect(manifest.bundledVersion.toString(), CodexRuntimeManifest.targetVersion);
      expect(manifest.minPathVersion.toString(), "0.139.0");
      expect(manifest.runtimeId, const CodexPluginDescriptor().id);
      expect(manifest.pathExecutableName, "codex");
      expect(manifest.binaryFileName, Platform.isWindows ? r"bin\codex.exe" : "bin/codex");
    });

    test("pins the canonical package and digest for every platform target", () {
      const expected = <PlatformOs, Map<PlatformArch, ({String assetName, String sha256})>>{
        PlatformOs.macos: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-apple-darwin.tar.gz",
            sha256: "dd99e9092270691a67bdde7be04ac283dea9da8e86cbde356c2cc851a79205fa",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-apple-darwin.tar.gz",
            sha256: "cfb2a9988d7ea448511166a35789af07a0065d1117db54350b17d46cf03d0294",
          ),
        },
        PlatformOs.linux: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-unknown-linux-musl.tar.gz",
            sha256: "5918add6c7e9cf1e14a9af1b4c0f4bf1d24a43903faac26df5dc4c019ea91bd5",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-unknown-linux-musl.tar.gz",
            sha256: "3ec55053109608d5038f7e50750f7d25f768dfd740fef071aa710e2559b63aac",
          ),
        },
        PlatformOs.windows: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-pc-windows-msvc.tar.gz",
            sha256: "735deb6af84fd927084429f7a371ee38670a013baace6df24985780f7ef67355",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-pc-windows-msvc.tar.gz",
            sha256: "700116be3143576d006467af8576f7f4c9dada1feddfdb7f69743bfde0997018",
          ),
        },
      };

      for (final osEntry in expected.entries) {
        for (final archEntry in osEntry.value.entries) {
          final asset = manifest.assetFor(
            target: PlatformTarget(os: osEntry.key, arch: archEntry.key),
          );
          expect(asset, isA<ArchiveRuntimeAsset>(), reason: "${osEntry.key}/${archEntry.key} asset type");
          final archive = asset! as ArchiveRuntimeAsset;
          expect(archive.assetName, archEntry.value.assetName);
          expect(archive.sha256, archEntry.value.sha256);
          expect(archive.format, ArchiveFormat.tarGz);
          expect(archive.layout, RuntimeArchiveLayout.packageDirectory);
          expect(
            archive.archiveBinaryName,
            osEntry.key == PlatformOs.windows ? "bin/codex.exe" : "bin/codex",
          );
        }
      }
    });

    test("download URL embeds the rust-v bundled tag and asset name", () {
      final asset = manifest.assetFor(
        target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
      )!;
      expect(
        manifest.downloadUrlFor(asset: asset),
        equals(
          "https://github.com/openai/codex/releases/download/"
          "rust-v0.164.0/codex-package-aarch64-apple-darwin.tar.gz",
        ),
      );
    });

    test("bundled version is at least the minimum PATH version", () {
      expect(manifest.bundledVersion.compareTo(manifest.minPathVersion), greaterThanOrEqualTo(0));
    });
  });
}
