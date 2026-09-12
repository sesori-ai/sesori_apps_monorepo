import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../pi_identity.dart";

/// Pinned official Pi package archives used by managed installation.
class const PiRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "0.84.1");

  /// The latest stable Pi release targeted by this plugin.
  static const String targetVersion = "0.85.1";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "d5f70e3c0cf7398eac239fd0261ee074d98b7ba7f6b43fe3617f052ed5b79d06",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "adb918b845625f184d8bea408d55eacaf21aa87238793c0f5b4f3b9737bce62b",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "042d20ae885ee4f3b102815f3280b962c377b2e9fb44de4037908cc530eae4d4",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "494e498f47d74d21f40b3386f6a5e921a3d49531a169cab55bbdaca0ea1fe25a",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-windows-arm64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "b25e96fe64c9f41f75a924c0d36f395abb98d6c6fec0b78aaa0b86926f938bb4",
        archiveBinaryName: "pi.exe",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-windows-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "002fa95b90d521245b9985d8f168caebc237ad56e7e30b319807dee1b2e17e1c",
        archiveBinaryName: "pi.exe",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
  };

  @override
  String get runtimeId => PiPluginIdentity.id;

  @override
  String get displayName => PiPluginIdentity.displayName;

  @override
  String get installDocsUrl => "https://github.com/earendil-works/pi";

  @override
  String get pathExecutableName => "pi";

  @override
  String get binaryFileName => Platform.isWindows ? "pi.exe" : "pi";

  @override
  RuntimeVersion get minPathVersion => _minPathVersion;

  @override
  RuntimeVersion get bundledVersion => _bundledVersion;

  @override
  RuntimeVersion? parseVersion({required String value}) => SemanticRuntimeVersion.tryParse(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => _assets[target.os]?[target.arch];

  @override
  String downloadUrlFor({required RuntimeAsset asset}) =>
      githubReleaseAssetUrl(repository: "earendil-works/pi", tag: "v${bundledVersion.raw}", asset: asset);
}
