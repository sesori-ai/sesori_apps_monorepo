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
    expect(manifest.bundledVersion.raw, "0.1.6");
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
        "sesori-deepseek-acp-v0.1.6-darwin-arm64.tar.gz":
            "c0763ea25a2ebe85bfa0327e4d75492fc2d3e40c7af6694f3fdf8b1eee8befce",
        "sesori-deepseek-acp-v0.1.6-darwin-x64.tar.gz":
            "54eb6d599307b16808ed47322b48b93fb94083d90816fb32de93c393042414b9",
        "sesori-deepseek-acp-v0.1.6-linux-arm64.tar.gz":
            "eae26c2091cca61d9aeea363caea425bbad7c5b7b8bcab9df5ff77d26e817047",
        "sesori-deepseek-acp-v0.1.6-linux-x64.tar.gz":
            "7746c6d6a9dfb142c8f7c7f5d1c849dc82cea0de34b29ce6703c9e7dca3afea1",
        "sesori-deepseek-acp-v0.1.6-windows-arm64.zip":
            "591eb5fb1105672e64845770e6db86604431d0fdcb54328fcd49a5452da5e24c",
        "sesori-deepseek-acp-v0.1.6-windows-x64.zip":
            "0fc4a31940cb61798d79fd849b469b7f2484e78fc58091cceeec392748bce660",
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
      "https://github.com/sesori-ai/sesori-deepseek-acp/releases/download/v0.1.6/sesori-deepseek-acp-v0.1.6-darwin-arm64.tar.gz",
    );
  });
}
