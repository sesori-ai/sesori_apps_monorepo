import "dart:io" show Platform;

import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = DeepSeekRuntimeManifest();

  test("pins the compatible PATH floor and latest managed release", () {
    expect(manifest.runtimeId, "deepseek");
    expect(manifest.pathExecutableName, "sesori-deepseek-acp");
    expect(
      manifest.binaryFileName,
      Platform.isWindows ? "sesori-deepseek-acp.cmd" : "sesori-deepseek-acp",
    );
    expect(manifest.minPathVersion.raw, "0.1.5");
    expect(manifest.minPathVersion.raw, DeepSeekPluginDescriptor.minVersion);
    expect(manifest.bundledVersion.raw, "0.1.7");
    expect(manifest.parseVersion(value: "sesori-deepseek-acp/0.1.0")?.raw, "0.1.0");
  });

  test("maps all six immutable package-directory archives", () {
    final assets = <ArchiveRuntimeAsset>[
      for (final target in const [
        PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
        PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64),
        PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.arm64),
        PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64),
        PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.arm64),
        PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64),
      ])
        manifest.assetFor(target: target)! as ArchiveRuntimeAsset,
    ];

    expect(
      {for (final asset in assets) asset.assetName: asset.sha256},
      {
        "sesori-deepseek-acp-v0.1.7-darwin-arm64.tar.gz":
            "800c054403a9be01a68ff71a0315c05cf3a854891c7b004f24cc9514a697d67b",
        "sesori-deepseek-acp-v0.1.7-darwin-x64.tar.gz":
            "74b2ed9a630f84b804c7d3184eda62125f9c9cb9723957a5c166d657af9586ce",
        "sesori-deepseek-acp-v0.1.7-linux-arm64.tar.gz":
            "d356a85050d1c1525c41ed29ea327ea0df6888983cfab32ed5c452ef57e7d79b",
        "sesori-deepseek-acp-v0.1.7-linux-x64.tar.gz":
            "ace7c89372d40e358ddc804292056a8260b8acd0337b88b87aec7034f583a5ec",
        "sesori-deepseek-acp-v0.1.7-windows-arm64.zip":
            "642723f499f4452d09bd75ab1b67c70894e65383c0b08e82597e89e86b77f3a7",
        "sesori-deepseek-acp-v0.1.7-windows-x64.zip":
            "9a342a51535cdd876aa6084a3e80d08f3e6f8fe5ea91a64eba8a2a34b2c3f14c",
      },
    );
    expect(
      assets,
      everyElement(
        predicate<ArchiveRuntimeAsset>(
          (asset) =>
              asset.layout == RuntimeArchiveLayout.packageDirectory && RegExp(r"^[0-9a-f]{64}$").hasMatch(asset.sha256),
        ),
      ),
    );
  });

  test("builds the immutable GitHub release URL", () {
    final asset = manifest.assetFor(
      target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
    )!;
    expect(
      manifest.downloadUrlFor(asset: asset),
      "https://github.com/sesori-ai/sesori-deepseek-acp/releases/download/v0.1.7/sesori-deepseek-acp-v0.1.7-darwin-arm64.tar.gz",
    );
  });
}
