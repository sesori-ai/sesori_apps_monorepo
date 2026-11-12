import "dart:io" show Platform;

import "package:pi_plugin/pi_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = PiRuntimeManifest();

  test("keeps the verified PATH floor and pins managed Pi v1.5.2", () {
    expect(manifest.runtimeId, "pi");
    expect(manifest.pathExecutableName, "pi");
    expect(manifest.binaryFileName, Platform.isWindows ? "pi.exe" : "pi");
    expect(manifest.minPathVersion.raw, "0.99.0");
    expect(PiRuntimeManifest.targetVersion, "1.5.2");
    expect(manifest.bundledVersion.raw, PiRuntimeManifest.targetVersion);
    expect(manifest.parseVersion(value: "0.99.2")?.raw, "0.99.2");
    expect(manifest.parseVersion(value: "pi/0.99.2"), isNull);
  });

  test("maps all six official package-directory archives", () {
    final assets = <ArchiveRuntimeAsset>[
      for (final target in const [
        PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
        PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64),
        PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.arm64),
        PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64),
        PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.arm64),
        PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64),
      ])
        switch (manifest.assetFor(target: target)) {
          final ArchiveRuntimeAsset asset => asset,
          final other => fail("expected an archive asset for $target, got $other"),
        },
    ];

    expect(assets.map((asset) => asset.assetName), {
      "pi-darwin-arm64.tar.gz",
      "pi-darwin-x64.tar.gz",
      "pi-linux-arm64.tar.gz",
      "pi-linux-x64.tar.gz",
      "pi-windows-arm64.zip",
      "pi-windows-x64.zip",
    });
    expect(
      assets,
      everyElement(
        predicate<ArchiveRuntimeAsset>((asset) => asset.layout == RuntimeArchiveLayout.packageDirectory),
      ),
    );
    const expectedSha256 = {
      "pi-darwin-arm64.tar.gz": "56b5e194d485ced555667b8ba3276157a8272e9ecde9e001e428af80985bdd9b",
      "pi-darwin-x64.tar.gz": "f997a088613514ac97d913aeea7642094d84fe6d46854ff7e64e2c12e536dc50",
      "pi-linux-arm64.tar.gz": "42805cd5615952fcbbfc9c56b04f8feb84395134952e169a6cdc8d7676975666",
      "pi-linux-x64.tar.gz": "811c6f2c9e7aaee252b5404252e556fb713aa209c1f7f924226aa77d4ef70cb5",
      "pi-windows-arm64.zip": "e83404bc5a6003ac950683edd9b6cf499dac91ec890d8439a8c32528de534a77",
      "pi-windows-x64.zip": "e6adb8cb8c84eca14391ad24b363de9d2be98a89ca3ba3fdee1fa4de32b7f2e8",
    };
    expect(
      {for (final asset in assets) asset.assetName: asset.sha256},
      expectedSha256,
    );
    expect(
      assets.take(4),
      everyElement(predicate<ArchiveRuntimeAsset>((asset) => asset.archiveBinaryName == "pi")),
    );
    expect(
      assets.skip(4),
      everyElement(predicate<ArchiveRuntimeAsset>((asset) => asset.archiveBinaryName == "pi.exe")),
    );
  });

  test("builds the official release URL with the v tag", () {
    final asset =
        manifest.assetFor(
          target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
        ) ??
        fail("missing macOS arm64 asset");
    expect(
      manifest.downloadUrlFor(asset: asset),
      "https://github.com/earendil-works/pi/releases/download/v1.5.2/pi-darwin-arm64.tar.gz",
    );
  });
}
