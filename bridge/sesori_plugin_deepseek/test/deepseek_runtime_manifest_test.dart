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
    expect(manifest.bundledVersion.raw, "0.2.2");
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
        "sesori-deepseek-acp-v0.2.2-darwin-arm64.tar.gz":
            "683a70598f7a4ffe76c412080cb74e4cd2be3d1f8f8900146b6b148a955bdd1e",
        "sesori-deepseek-acp-v0.2.2-darwin-x64.tar.gz":
            "2dcc0b22ee26934ddb5bc024cf723f4ecb69b28c78149e5be54124bebba06d27",
        "sesori-deepseek-acp-v0.2.2-linux-arm64.tar.gz":
            "6eebd9ca319b0e03b911019fbf6b26c1195203fb21dc377c491ff4ff24018868",
        "sesori-deepseek-acp-v0.2.2-linux-x64.tar.gz":
            "e6604ab31341c0e0a379040399fc968b282a98c2152c123a585ef47c493a85d8",
        "sesori-deepseek-acp-v0.2.2-windows-arm64.zip":
            "97e61a4647fb6bc00a239b4426a0adb49d9b1f34abba359225aff3fc8f48de65",
        "sesori-deepseek-acp-v0.2.2-windows-x64.zip":
            "eb53ffb858307a844e7b98929fb19c0d441a7d53d8a0e024ad34e3360b5c8eba",
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
      "https://github.com/sesori-ai/sesori-deepseek-acp/releases/download/v0.2.2/sesori-deepseek-acp-v0.2.2-darwin-arm64.tar.gz",
    );
  });
}
