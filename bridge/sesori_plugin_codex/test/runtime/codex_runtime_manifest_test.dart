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
      expect(CodexRuntimeManifest.targetVersion, "0.154.0");
      expect(manifest.bundledVersion.toString(), CodexRuntimeManifest.targetVersion);
      expect(manifest.minPathVersion.toString(), "0.148.0");
      expect(manifest.runtimeId, const CodexPluginDescriptor().id);
      expect(manifest.pathExecutableName, "codex");
      expect(manifest.binaryFileName, Platform.isWindows ? r"bin\codex.exe" : "bin/codex");
    });

    test("pins the canonical package and digest for every platform target", () {
      const expected = <PlatformOs, Map<PlatformArch, ({String assetName, String sha256})>>{
        PlatformOs.macos: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-apple-darwin.tar.gz",
            sha256: "427ca74c027049e0cd1a330d611e7f8d1fe0f1eb6a6d85ac16f61bcf2cb4a485",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-apple-darwin.tar.gz",
            sha256: "8052c6accbe0361bfbd424a10aa5f2226636ed8afb6dcbd5e6437993e57b16d8",
          ),
        },
        PlatformOs.linux: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-unknown-linux-musl.tar.gz",
            sha256: "97d93e11df72d3c26772db019e6ea8bb72c246500d46b98c760839f3240355e6",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-unknown-linux-musl.tar.gz",
            sha256: "fc6e3e3b85f2cf7d664520ee5c66a7fe4aa12bae7d46834f47e2f165fd0d6f78",
          ),
        },
        PlatformOs.windows: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-pc-windows-msvc.tar.gz",
            sha256: "fcd888733e50e40acaf4278bedfbf4245cb2b934c99c6e5b263da850fd9f90c2",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-pc-windows-msvc.tar.gz",
            sha256: "94cc5b3632769504c809f6c0364b693c0dfddc5c30c8361095d2263a07ac45a4",
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
          "rust-v0.154.0/codex-package-aarch64-apple-darwin.tar.gz",
        ),
      );
    });

    test("bundled version is at least the minimum PATH version", () {
      expect(manifest.bundledVersion.compareTo(manifest.minPathVersion), greaterThanOrEqualTo(0));
    });
  });
}
