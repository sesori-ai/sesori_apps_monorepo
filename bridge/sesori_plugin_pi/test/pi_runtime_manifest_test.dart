import "dart:io" show Platform;

import "package:pi_plugin/pi_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = PiRuntimeManifest();

  test("keeps the verified PATH floor and pins managed Pi v1.6.1", () {
    expect(manifest.runtimeId, "pi");
    expect(manifest.pathExecutableName, "pi");
    expect(manifest.binaryFileName, Platform.isWindows ? "pi.exe" : "pi");
    expect(manifest.minPathVersion.raw, "0.99.0");
    expect(PiRuntimeManifest.targetVersion, "1.6.1");
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
      "pi-darwin-arm64.tar.gz": "d8fd8e24c2a5054ae383d83b26f6eb6f950edf613917e434a52394f44cd4d933",
      "pi-darwin-x64.tar.gz": "5c2df5744c7828cc8b78c5665a3a785cc073130005c711d35017c6a5c419169a",
      "pi-linux-arm64.tar.gz": "afde641d6c5904d26960ddb4223bf563b0860cf1a0ebc443b85deff67d048753",
      "pi-linux-x64.tar.gz": "3c7f00715eb512e165c0da8cad314d73c83b54d5bf7748be4adc618fc8357b68",
      "pi-windows-arm64.zip": "1d573e8b02f92d3cc3d386481710144f9091a93775d211663919da9ed4c9d31d",
      "pi-windows-x64.zip": "dbb007c8c50782de1642382fed777c60252aab080f36eef7823324c574c1f3e4",
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
      "https://github.com/earendil-works/pi/releases/download/v1.6.1/pi-darwin-arm64.tar.gz",
    );
  });
}
