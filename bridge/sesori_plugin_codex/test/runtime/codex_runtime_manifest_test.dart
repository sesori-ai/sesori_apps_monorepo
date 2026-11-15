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
      expect(CodexRuntimeManifest.targetVersion, "0.169.0");
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
            sha256: "8a232260df7a12c5e83e0b4b7659e1c8d9259b41942517bc0068d8ab55c36461",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-apple-darwin.tar.gz",
            sha256: "0a3c392235b4712409495ced02bbe0662ce7a038232766d1c1c34af74e905c2f",
          ),
        },
        PlatformOs.linux: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-unknown-linux-musl.tar.gz",
            sha256: "c8d0b4ab2a97c595b70b10412d36d0d5464dcef1e1d3246b073d48017cdf5a4f",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-unknown-linux-musl.tar.gz",
            sha256: "3b8ed091149cc63a59046b9f094bcfa21cdb4dda15ede441ce369bcee4a71ba0",
          ),
        },
        PlatformOs.windows: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-pc-windows-msvc.tar.gz",
            sha256: "75318180f853d1846f6542f3f6409bfeae4553b91cac6aaaa08c64ee16e7a534",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-pc-windows-msvc.tar.gz",
            sha256: "456db280d16f4393cd99a398f11b4a14a3ede68b6bd31610ce41fb10d6b65737",
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
          "rust-v0.169.0/codex-package-aarch64-apple-darwin.tar.gz",
        ),
      );
    });

    test("bundled version is at least the minimum PATH version", () {
      expect(manifest.bundledVersion.compareTo(manifest.minPathVersion), greaterThanOrEqualTo(0));
    });
  });
}
