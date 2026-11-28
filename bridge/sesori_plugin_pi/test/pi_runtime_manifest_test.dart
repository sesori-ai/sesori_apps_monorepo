import "dart:io" show Platform;

import "package:pi_plugin/pi_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = PiRuntimeManifest();

  test("keeps the verified PATH floor and pins managed Pi v1.7.0", () {
    expect(manifest.runtimeId, "pi");
    expect(manifest.pathExecutableName, "pi");
    expect(manifest.binaryFileName, Platform.isWindows ? "pi.exe" : "pi");
    expect(manifest.minPathVersion.raw, "0.99.0");
    expect(PiRuntimeManifest.targetVersion, "1.7.0");
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
      "pi-darwin-arm64.tar.gz": "ff95a9ae160a55bb0417b35031a86c3fa52b39216999fba540b53568f2efc6eb",
      "pi-darwin-x64.tar.gz": "427d03ed20d14ddeddbe610f56cc7a493f5880f5800e0ecae174284a0a9c4691",
      "pi-linux-arm64.tar.gz": "cd209cfc90fb94fb4b00ccd785a8d64a4a154f924e52f88febeb6cf36d5c9a24",
      "pi-linux-x64.tar.gz": "42f7ed67e83f727fe51dd2746d50dc45c7d1784159a9518296a282402ac68f4a",
      "pi-windows-arm64.zip": "603d4eb1b85a233ba395aa0166c53fc219df56680a85332f0bdbfef0c98967f4",
      "pi-windows-x64.zip": "e98bb945fb7f6917a4bea1956759ce9faf07cf6bdd8c42bfef521eccf2276a17",
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
      "https://github.com/earendil-works/pi/releases/download/v1.7.0/pi-darwin-arm64.tar.gz",
    );
  });
}
