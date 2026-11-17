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
    expect(manifest.bundledVersion.raw, "0.2.4");
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
        (manifest.assetFor(target: target) ?? fail("no asset for $target")) as ArchiveRuntimeAsset,
    ];

    expect(
      {for (final asset in assets) asset.assetName: asset.sha256},
      {
        "sesori-deepseek-acp-v0.2.4-darwin-arm64.tar.gz":
            "21ff378c81f8bef40acb0c1692006065be7dd946f08cfb90956bdae6d162e4c4",
        "sesori-deepseek-acp-v0.2.4-darwin-x64.tar.gz":
            "ca6fde10cd99b0f579ce7bda333f538e4fb0faa23c407eebb7db5845345dca82",
        "sesori-deepseek-acp-v0.2.4-linux-arm64.tar.gz":
            "1e8195b0829298f400adb4b2f0941e6fdd72710cdf852d40138b595f210c6813",
        "sesori-deepseek-acp-v0.2.4-linux-x64.tar.gz":
            "55ffa687650b353e1f4162e225072430908d3825b09a7d5a7c46d35266beb565",
        "sesori-deepseek-acp-v0.2.4-windows-arm64.zip":
            "2d1dbf13c97d04ac027515ba1cff6a53e5a297453a05add9486a15a3dbcf9916",
        "sesori-deepseek-acp-v0.2.4-windows-x64.zip":
            "8be508356a00ec8bad8da2f8816a8b1b6fe92d7e18503b848a592488fa7f1410",
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
    final asset =
        manifest.assetFor(
          target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
        ) ??
        fail("no macOS arm64 asset");
    expect(
      manifest.downloadUrlFor(asset: asset),
      "https://github.com/sesori-ai/sesori-deepseek-acp/releases/download/v0.2.4/sesori-deepseek-acp-v0.2.4-darwin-arm64.tar.gz",
    );
  });
}
