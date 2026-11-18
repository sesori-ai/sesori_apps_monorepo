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
      expect(CodexPluginDescriptor.production().stateStorage, PluginStateStorage.legacySharedRuntime);
    });

    test("pinned versions", () {
      expect(CodexRuntimeManifest.targetVersion, "0.170.0");
      expect(manifest.bundledVersion.toString(), CodexRuntimeManifest.targetVersion);
      expect(manifest.minPathVersion.toString(), "0.139.0");
      expect(manifest.runtimeId, CodexPluginDescriptor.production().id);
      expect(manifest.pathExecutableName, "codex");
      expect(manifest.binaryFileName, Platform.isWindows ? r"bin\codex.exe" : "bin/codex");
    });

    test("pins the canonical package and digest for every platform target", () {
      const expected = <PlatformOs, Map<PlatformArch, ({String assetName, String sha256})>>{
        PlatformOs.macos: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-apple-darwin.tar.gz",
            sha256: "975524bf13aedd1b122d8d0e00c09ee67091b8f688c0b374943dbb3cf22c7893",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-apple-darwin.tar.gz",
            sha256: "2e971524460a570b913dbdc9b49e5e9c14556e44e7f62f00b95b4a8f1e2cdf25",
          ),
        },
        PlatformOs.linux: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-unknown-linux-musl.tar.gz",
            sha256: "3f7e1ae38c4fe27322e082b855e8eec936d08fa538d62b71c07e2a53f34e8847",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-unknown-linux-musl.tar.gz",
            sha256: "a77ff87be7ba809d715728270a78f5ce3527dc07529416d1ef8929b90b8475eb",
          ),
        },
        PlatformOs.windows: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-pc-windows-msvc.tar.gz",
            sha256: "11a5c2cc39c1405317d3f7d117b727845bec166a9f8d0636c265e9bfdd5aa354",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-pc-windows-msvc.tar.gz",
            sha256: "6ff4b22c63645ffd83aed9b722cbb0b9e5b79dc6e8916f50e362b3015fb327a9",
          ),
        },
      };

      for (final osEntry in expected.entries) {
        for (final archEntry in osEntry.value.entries) {
          final asset = manifest.assetFor(
            target: PlatformTarget(os: osEntry.key, arch: archEntry.key),
          );
          if (asset is! ArchiveRuntimeAsset) fail("${osEntry.key}/${archEntry.key} asset type: $asset");
          final archive = asset;
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
      final asset =
          manifest.assetFor(
            target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
          ) ??
          fail("macOS arm64 asset is missing");
      expect(
        manifest.downloadUrlFor(asset: asset),
        equals(
          "https://github.com/openai/codex/releases/download/"
          "rust-v0.170.0/codex-package-aarch64-apple-darwin.tar.gz",
        ),
      );
    });

    test("bundled version is at least the minimum PATH version", () {
      expect(manifest.bundledVersion.compareTo(manifest.minPathVersion), greaterThanOrEqualTo(0));
    });
  });
}
