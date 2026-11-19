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
    expect(manifest.bundledVersion.raw, "0.2.5");
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
        "sesori-deepseek-acp-v0.2.5-darwin-arm64.tar.gz":
            "199569c89f77ad955cc4c22535fae9348ff9817ef72a75d4810ac2e8e45f5787",
        "sesori-deepseek-acp-v0.2.5-darwin-x64.tar.gz":
            "aa87abff46dd13f8f8a1b79d138b97f7a8baab208c5eb0bdfa0a0213985df1bd",
        "sesori-deepseek-acp-v0.2.5-linux-arm64.tar.gz":
            "2d9d3a9b7aae9f3fea9e82d036240018b1e92a28b81bedd5a62a33ac7c180776",
        "sesori-deepseek-acp-v0.2.5-linux-x64.tar.gz":
            "f3b8348a2b3060ba2f5173dee053b313af9ff097643fe8c191c2864bb831e4f9",
        "sesori-deepseek-acp-v0.2.5-windows-arm64.zip":
            "f97075c7ad3d6ce69158c5339ffd3476d674a67f891d48a8945b8256336ff465",
        "sesori-deepseek-acp-v0.2.5-windows-x64.zip":
            "79d18242405872258f17ae87a0aab8a3fb6e890ee2696c104d04bd72e61432a5",
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
      "https://github.com/sesori-ai/sesori-deepseek-acp/releases/download/v0.2.5/sesori-deepseek-acp-v0.2.5-darwin-arm64.tar.gz",
    );
  });
}
