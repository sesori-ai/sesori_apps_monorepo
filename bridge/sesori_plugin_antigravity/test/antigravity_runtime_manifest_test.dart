import "dart:io" show Platform;

import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = AntigravityRuntimeManifest();
  const macArm = PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64);
  const macX64 = PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64);
  const supportedTargets = [
    macArm,
    PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64),
    PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.arm64),
    PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64),
    PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.arm64),
  ];

  test("uses the official registry package version and managed directory layout", () {
    expect(manifest.runtimeId, AntigravityIdentity.pluginId);
    expect(manifest.displayName, AntigravityIdentity.displayName);
    expect(manifest.bundledVersion.raw, AntigravityRelease.registryPackageVersion);
    expect(manifest.minPathVersion, manifest.bundledVersion);
    expect(manifest.parseInstalledVersion(value: "1.0.0")?.raw, "1.0.0");
    expect(manifest.parseInstalledVersion(value: AntigravityRelease.agentVersion), isNull);
    expect(
      manifest.managedServerPath(stateDirectory: "/state", target: macArm),
      p.join(
        "/state",
        AntigravityIdentity.pluginId,
        AntigravityRelease.registryPackageVersion,
        AntigravityRelease.posixServerFileName,
      ),
    );
    expect(
      manifest.binaryFileName,
      Platform.isWindows ? AntigravityRelease.windowsServerFileName : AntigravityRelease.posixServerFileName,
    );
  });

  test("maps all five official archives as sibling-preserving packages", () {
    for (final target in supportedTargets) {
      final release = AntigravityRelease.artifactFor(target: target)!;
      final asset = manifest.assetFor(target: target)! as ArchiveRuntimeAsset;
      expect(asset.assetName, Uri.parse(release.archiveUrl).pathSegments.last);
      expect(asset.sha256, release.archiveSha256);
      expect(asset.format, ArchiveFormat.zip);
      expect(asset.archiveCommandTimeout, const Duration(minutes: 2));
      expect(asset.archiveBinaryName, AntigravityRelease.serverFileName(target: target));
      expect(asset.layout, RuntimeArchiveLayout.packageDirectory);
      expect(manifest.downloadUrlFor(asset: asset), release.archiveUrl);
      expect(manifest.supportsManagedInstallOn(target: target), isTrue);
    }
  });

  test("does not advertise macOS x64 or accept an unknown archive", () {
    expect(manifest.assetFor(target: macX64), isNull);
    expect(manifest.supportsManagedInstallOn(target: macX64), isFalse);
    expect(
      () => manifest.downloadUrlFor(
        asset: const ArchiveRuntimeAsset(
          assetName: "not-official.zip",
          format: ArchiveFormat.zip,
          archiveCommandTimeout: Duration(minutes: 2),
          sha256: "unused",
          archiveBinaryName: "unused",
          layout: RuntimeArchiveLayout.packageDirectory,
        ),
      ),
      throwsArgumentError,
    );
  });
}
